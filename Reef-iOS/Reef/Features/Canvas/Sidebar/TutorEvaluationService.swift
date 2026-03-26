import SwiftUI
import AVFoundation
@preconcurrency import Supabase

/// A single message in the tutor chat feed.
struct TutorChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let latex: String
    let timestamp: Date
    var confidenceResponse: String? = nil  // "shaky", "okay", "solid" — set when user responds

    enum Role: String {
        case student        // student's transcribed work or typed question
        case error          // tutor detected a mistake
        case reinforcement  // tutor celebrates step completion
        case answer         // tutor responds to a user question
        case confidenceCheck // "How confident are you?"
    }
}

/// Evaluates student handwriting against the answer key in real time.
/// Debounces requests by 900ms and discards stale responses via a generation counter.
@Observable
@MainActor
final class TutorEvaluationService {
    // MARK: - Public State

    var stepProgress: Double = 0.0
    var status: String = "idle"
    var mistakeExplanation: String?
    var isEvaluating: Bool = false
    var chatMessages: [TutorChatMessage] = []
    var voiceEnabled: Bool = true  // Set by CanvasViewModel based on user preference
    var isDemo: Bool = false       // During onboarding demo — no questions, no mic, no confidence check

    /// Fires when the model marks steps as completed. Parameter = number of steps completed (1+).
    var onStepCompleted: ((Int) -> Void)?

    /// Fires after a mistake's Socratic question is spoken — auto-enable mic for response.
    var onMistakeSpoken: (() -> Void)?

    /// Reinforcement text for the current step (from answer key).
    var pendingReinforcement: String?

    /// Fires when the tutor corrects its own answer key. CanvasViewModel should reload.
    var onAnswerKeyUpdated: (() -> Void)?

    /// Last debug prompt from the server (development only).
    var lastDebugPrompt: String?

    // MARK: - Private

    private var generation: Int = 0
    private var evaluateTask: Task<Void, Never>?
    private var lastEvaluatedLatex: String = ""
    private var previousStatus: String = "idle"

    private let recoveryPhrases = [
        "There you go.",
        "That's it, keep going.",
        "Nice fix.",
        "You got it.",
        "That's the one.",
        "Good catch.",
    ]

    private static let debounceInterval: Duration = .milliseconds(900)

    // MARK: - Evaluate

    /// Trigger an evaluation. Debounces by 900ms. Skips if latex is unchanged.
    func evaluate(
        latex: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        figureURLs: [String] = [],
        studentImage: String? = nil
    ) {
        // Skip if latex hasn't changed since last eval
        guard !latex.isEmpty, latex != lastEvaluatedLatex else {
            return
        }

        // Cancel any pending debounce and restart with new latex
        evaluateTask?.cancel()
        generation += 1
        let myGeneration = generation

        evaluateTask = Task { [weak self] in
            // Debounce
            try? await Task.sleep(for: Self.debounceInterval)
            guard let self, !Task.isCancelled, self.generation == myGeneration else {
                await MainActor.run { self?.evaluateTask = nil }
                return
            }

            self.isEvaluating = true
            defer {
                self.isEvaluating = false
                self.evaluateTask = nil
            }

            do {
                let response = try await self.callServer(
                    latex: latex,
                    documentId: documentId,
                    questionNumber: questionNumber,
                    partLabel: partLabel,
                    stepIndex: stepIndex,
                    figureURLs: figureURLs,
                    studentImage: studentImage
                )

                guard self.generation == myGeneration else { return }

                let wasInMistake = self.previousStatus == "mistake"
                self.stepProgress = response.progress
                self.status = response.status
                self.previousStatus = response.status
                self.mistakeExplanation = response.mistakeExplanation
                self.lastDebugPrompt = response.debugPrompt
                self.lastEvaluatedLatex = latex

                // Mistake recovery — student fixed the error and is back on track
                if wasInMistake && response.status == "working" {
                    let phrase = self.recoveryPhrases.randomElement() ?? "There you go."
                    self.chatMessages.append(TutorChatMessage(
                        role: .reinforcement, latex: phrase, timestamp: Date()
                    ))
                    if self.voiceEnabled {
                        // Speak recovery phrase via TTS
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                                  let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
                                  let token = try? await supabase.auth.session.accessToken else { return }
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.timeoutInterval = 10
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": phrase])
                            guard let (data, resp) = try? await URLSession.shared.data(for: request),
                                  let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
                            struct TTSResp: Decodable { let speechAudio: String?; enum CodingKeys: String, CodingKey { case speechAudio = "speech_audio" } }
                            guard let result = try? JSONDecoder().decode(TTSResp.self, from: data),
                                  let b64 = result.speechAudio,
                                  let audioData = Data(base64Encoded: b64) else { return }
                            self.playAudio(audioData)
                        }
                    }
                }

                // Add chat messages for mistakes
                if let mistake = response.mistakeExplanation, response.status == "mistake" {
                    let now = Date()
                    self.chatMessages.append(TutorChatMessage(
                        role: .student, latex: latex, timestamp: now
                    ))
                    self.chatMessages.append(TutorChatMessage(
                        role: .error, latex: mistake, timestamp: now
                    ))
                }

                // Play TTS audio BEFORE step advancement so isTutorSpeaking is true
                // when advanceTutorSteps polls for it
                if self.voiceEnabled,
                   let audioBase64 = response.speechAudio,
                   let audioData = Data(base64Encoded: audioBase64) {
                    self.playAudio(audioData)

                    // After Socratic mistake question finishes, auto-enable mic
                    if response.status == "mistake" {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            // Wait for audio to finish
                            var waited = 0
                            while self.isTutorSpeaking && waited < 75 {
                                try? await Task.sleep(for: .milliseconds(200))
                                waited += 1
                            }
                            try? await Task.sleep(for: .milliseconds(300))
                            if !self.isDemo { self.onMistakeSpoken?() }
                        }
                    }
                }

                // Step completed — show reinforcement, confidence check, then advance
                if response.status == "completed" {
                    if let reinforcement = self.pendingReinforcement, !reinforcement.isEmpty {
                        self.chatMessages.removeAll { $0.role == .reinforcement }
                        self.chatMessages.append(TutorChatMessage(
                            role: .reinforcement, latex: reinforcement, timestamp: Date()
                        ))
                    }
                    // Add confidence check (skip during demo)
                    if !isDemo {
                        self.chatMessages.append(TutorChatMessage(
                            role: .confidenceCheck,
                            latex: "How confident are you in that step?",
                            timestamp: Date()
                        ))
                    }
                    self.onStepCompleted?(response.stepsCompleted)
                }
            } catch {
                guard !Task.isCancelled, self.generation == myGeneration else { return }
                print("[TutorEvalSvc] Evaluation failed: \(error)")
            }
        }
    }

    // MARK: - Reset

    /// Reset for a new step (keeps chat history).
    func resetForNextStep() {
        evaluateTask?.cancel()
        evaluateTask = nil
        generation += 1
        stepProgress = 0.0
        status = "idle"
        previousStatus = "idle"
        mistakeExplanation = nil
        isEvaluating = false
        lastEvaluatedLatex = ""
    }

    /// Full reset (tutor mode toggled off or question changed).
    func reset() {
        resetForNextStep()
        chatTask?.cancel()
        chatTask = nil
        chatMessages.removeAll()
    }

    // MARK: - Network

    private struct EvalResponse: Decodable {
        let progress: Double
        let status: String
        let mistakeExplanation: String?
        let stepsCompleted: Int
        let speechAudio: String?
        let debugPrompt: String?

        enum CodingKeys: String, CodingKey {
            case progress, status
            case mistakeExplanation = "mistake_explanation"
            case stepsCompleted = "steps_completed"
            case speechAudio = "speech_audio"
            case debugPrompt = "debug_prompt"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            progress = try container.decode(Double.self, forKey: .progress)
            status = try container.decode(String.self, forKey: .status)
            mistakeExplanation = try container.decodeIfPresent(String.self, forKey: .mistakeExplanation)
            stepsCompleted = try container.decodeIfPresent(Int.self, forKey: .stepsCompleted) ?? 1
            speechAudio = try container.decodeIfPresent(String.self, forKey: .speechAudio)
            debugPrompt = try container.decodeIfPresent(String.self, forKey: .debugPrompt)
        }
    }

    private struct HistoryEntry: Encodable {
        let role: String
        let text: String
    }

    private struct EvalRequest: Encodable {
        let documentId: String
        let questionNumber: Int
        let partLabel: String?
        let stepIndex: Int
        let studentLatex: String
        let figureUrls: [String]
        let studentImage: String?
        let history: [HistoryEntry]
        let isDemo: Bool

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case questionNumber = "question_number"
            case partLabel = "part_label"
            case stepIndex = "step_index"
            case studentLatex = "student_latex"
            case figureUrls = "figure_urls"
            case studentImage = "student_image"
            case history
            case isDemo = "is_demo"
        }
    }

    private func callServer(
        latex: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        figureURLs: [String],
        studentImage: String? = nil
    ) async throws -> EvalResponse {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/tutor-evaluate") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session

        // Send last 15 chat messages as context
        let historyEntries = chatMessages.suffix(15).map { msg in
            HistoryEntry(role: msg.role.rawValue, text: msg.latex)
        }

        let body = EvalRequest(
            documentId: documentId,
            questionNumber: questionNumber,
            partLabel: partLabel,
            stepIndex: stepIndex,
            studentLatex: latex,
            figureUrls: figureURLs,
            studentImage: studentImage,
            history: historyEntries,
            isDemo: isDemo
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(EvalResponse.self, from: data)
    }

    // MARK: - Chat

    var isSendingChat: Bool = false
    private var chatTask: Task<Void, Never>?

    /// Send a user question to the tutor and get a reply.
    func sendChat(
        message: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        studentLatex: String,
        studentImage: String? = nil
    ) {
        guard !isSendingChat else { return }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add user message immediately
        chatMessages.append(TutorChatMessage(
            role: .student, latex: trimmed, timestamp: Date()
        ))

        isSendingChat = true

        chatTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.callChatServer(
                    message: trimmed,
                    documentId: documentId,
                    questionNumber: questionNumber,
                    partLabel: partLabel,
                    stepIndex: stepIndex,
                    studentLatex: studentLatex,
                    studentImage: studentImage
                )
                self.chatMessages.append(TutorChatMessage(
                    role: .answer, latex: response.reply, timestamp: Date()
                ))
                // Play TTS audio if voice enabled
                if self.voiceEnabled,
                   let audioBase64 = response.speechAudio,
                   let audioData = Data(base64Encoded: audioBase64) {
                    self.playAudio(audioData)
                }
                // If the tutor corrected its answer key, notify CanvasViewModel to reload
                if response.answerKeyUpdated {
                    self.onAnswerKeyUpdated?()
                }
            } catch {
                self.chatMessages.append(TutorChatMessage(
                    role: .answer, latex: "Couldn't reach the tutor right now. Try again in a moment.", timestamp: Date()
                ))
            }
            self.isSendingChat = false
        }
    }

    private struct HistoryMessage: Encodable {
        let role: String
        let text: String
    }

    private struct ChatRequest: Encodable {
        let documentId: String
        let questionNumber: Int
        let partLabel: String?
        let stepIndex: Int
        let studentLatex: String
        let userMessage: String
        let history: [HistoryMessage]
        let studentImage: String?

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case questionNumber = "question_number"
            case partLabel = "part_label"
            case stepIndex = "step_index"
            case studentLatex = "student_latex"
            case userMessage = "user_message"
            case history
            case studentImage = "student_image"
        }
    }

    private struct ChatResponse: Decodable {
        let reply: String
        let speechAudio: String?
        let answerKeyUpdated: Bool

        enum CodingKeys: String, CodingKey {
            case reply
            case speechAudio = "speech_audio"
            case answerKeyUpdated = "answer_key_updated"
        }
    }

    private func callChatServer(
        message: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        studentLatex: String,
        studentImage: String? = nil
    ) async throws -> ChatResponse {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/tutor-chat") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session

        // Send last 10 messages as history
        let historyMessages = chatMessages.suffix(10).map { msg in
            HistoryMessage(role: msg.role.rawValue, text: msg.latex)
        }

        let body = ChatRequest(
            documentId: documentId,
            questionNumber: questionNumber,
            partLabel: partLabel,
            stepIndex: stepIndex,
            studentLatex: studentLatex,
            userMessage: message,
            history: historyMessages,
            studentImage: studentImage
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }

    // MARK: - Audio Playback

    var isTutorSpeaking: Bool = false
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: AudioFinishDelegate?

    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isTutorSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func playAudio(_ data: Data) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(data: data)
            let delegate = AudioFinishDelegate { [weak self] in
                Task { @MainActor in
                    self?.isTutorSpeaking = false
                }
            }
            player.delegate = delegate
            audioDelegate = delegate
            audioPlayer = player
            isTutorSpeaking = true
            player.play()
        } catch {
            print("[TutorEval] Audio playback failed: \(error)")
            isTutorSpeaking = false
        }
    }
}

// MARK: - Audio Delegate

private final class AudioFinishDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish()
    }
}
