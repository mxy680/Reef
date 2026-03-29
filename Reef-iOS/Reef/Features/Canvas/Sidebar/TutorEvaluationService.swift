import SwiftUI
import AVFoundation
@preconcurrency import Supabase

/// A single message in the tutor chat feed.
struct TutorChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let latex: String
    let timestamp: Date
    var confidenceResponse: String? = nil

    enum Role: String {
        case student
        case error
        case reinforcement
        case answer
        case confidenceCheck
    }
}

/// Evaluates student handwriting against the answer key in real time.
@Observable
@MainActor
final class TutorEvaluationService {
    // MARK: - Public State

    var stepProgress: Double = 0.0
    var status: String = "idle"
    var mistakeExplanation: String?
    var isEvaluating: Bool = false
    private var madeMistakeOnCurrentStep: Bool = false
    var chatMessages: [TutorChatMessage] = []
    var voiceEnabled: Bool = true
    var isDemo: Bool = false

    var onStepCompleted: ((Int) -> Void)?
    var onMistakeSpoken: (() -> Void)?
    var pendingReinforcement: String?
    var onAnswerKeyUpdated: (() -> Void)?

    var lastDebugPrompt: String?
    var evalCount: Int = 0

    // MARK: - Private

    private var previousStatus: String = "idle"

    private let recoveryPhrases = [
        "There you go.", "That's it, keep going.", "Nice fix.",
        "You got it.", "That's the one.", "Good catch.",
    ]

    // MARK: - Evaluate (async, no Task spawning)

    /// Call the server and process the response. Awaitable — caller controls timing.
    func runEval(
        latex: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        figureURLs: [String] = [],
        studentImage: String? = nil
    ) async {
        guard !latex.isEmpty else {
            print("[runEval] SKIPPED: empty latex")
            return
        }

        print("[runEval] START: step=\(stepIndex) latex=\(latex.prefix(50))")
        isEvaluating = true
        defer {
            isEvaluating = false
            print("[runEval] END")
        }

        do {
            let response = try await callServer(
                latex: latex,
                documentId: documentId,
                questionNumber: questionNumber,
                partLabel: partLabel,
                stepIndex: stepIndex,
                figureURLs: figureURLs,
                studentImage: studentImage
            )

            print("[runEval] RESPONSE: status=\(response.status) progress=\(response.progress) steps=\(response.stepsCompleted) speech=\(response.speechText?.prefix(40) ?? "nil")")
            let wasInMistake = previousStatus == "mistake"
            stepProgress = response.progress
            previousStatus = response.status
            mistakeExplanation = response.mistakeExplanation
            lastDebugPrompt = response.debugPrompt
            evalCount += 1

            // Mistake recovery
            if wasInMistake && response.status == "working" {
                let phrase = recoveryPhrases.randomElement() ?? "There you go."
                chatMessages.append(TutorChatMessage(role: .reinforcement, latex: phrase, timestamp: Date()))
                if voiceEnabled { await speakPhrase(phrase) }
            }

            // Track mistakes for confidence check
            if response.status == "mistake" {
                madeMistakeOnCurrentStep = true
            }

            // Show speech text in chat — exactly what the tutor says verbally
            // This is the single source of truth for all tutor feedback display
            if let speechText = response.speechText, !speechText.isEmpty {
                let role: TutorChatMessage.Role = response.status == "mistake" ? .error : .reinforcement
                if chatMessages.last?.latex != speechText {
                    chatMessages.append(TutorChatMessage(role: role, latex: speechText, timestamp: Date()))
                }
            }

            // Confidence check after struggled step completion
            if response.status == "completed" && !isDemo && madeMistakeOnCurrentStep {
                chatMessages.append(TutorChatMessage(role: .confidenceCheck, latex: "How confident are you in that step?", timestamp: Date()))
            }

            // Play TTS audio (non-blocking — audio plays in background)
            if voiceEnabled, let audioBase64 = response.speechAudio,
               let audioData = Data(base64Encoded: audioBase64) {
                playAudio(audioData)
            }

            // Set status and fire step advancement immediately
            status = response.status
            if response.status == "completed" {
                onStepCompleted?(response.stepsCompleted)
            }
        } catch {
            print("[TutorEvalSvc] Evaluation failed: \(error)")
        }
    }

    // MARK: - Reset

    func resetForNextStep() {
        stepProgress = 0.0
        status = "idle"
        previousStatus = "idle"
        mistakeExplanation = nil
        isEvaluating = false
        madeMistakeOnCurrentStep = false
    }

    func reset() {
        resetForNextStep()
        chatTask?.cancel()
        chatTask = nil
        chatMessages.removeAll()
    }

    // MARK: - Process Eval Response (called directly from CanvasViewModel.fireEval)

    func processEvalResponse(
        progress: Double,
        status: String,
        mistakeExplanation: String?,
        stepsCompleted: Int,
        speechAudio: String?,
        speechText: String?
    ) async {
        let wasInMistake = previousStatus == "mistake"
        stepProgress = progress
        previousStatus = status
        self.mistakeExplanation = mistakeExplanation
        evalCount += 1

        // Mistake recovery
        if wasInMistake && status == "working" {
            let phrase = recoveryPhrases.randomElement() ?? "There you go."
            chatMessages.append(TutorChatMessage(role: .reinforcement, latex: phrase, timestamp: Date()))
            if voiceEnabled { await speakPhrase(phrase) }
        }

        // Track mistakes for confidence check
        if status == "mistake" {
            madeMistakeOnCurrentStep = true
        }

        // Show speech text in chat
        if let speechText, !speechText.isEmpty {
            let role: TutorChatMessage.Role = status == "mistake" ? .error : .reinforcement
            if chatMessages.last?.latex != speechText {
                chatMessages.append(TutorChatMessage(role: role, latex: speechText, timestamp: Date()))
            }
        }

        // Confidence check after struggled step completion
        if status == "completed" && !isDemo && madeMistakeOnCurrentStep {
            chatMessages.append(TutorChatMessage(role: .confidenceCheck, latex: "How confident are you in that step?", timestamp: Date()))
        }

        // Play TTS audio
        if voiceEnabled, let audioBase64 = speechAudio,
           let audioData = Data(base64Encoded: audioBase64) {
            playAudio(audioData)
        }

        self.status = status
    }

    // MARK: - Network (Eval)

    private struct EvalResponse: Decodable {
        let progress: Double
        let status: String
        let mistakeExplanation: String?
        let stepsCompleted: Int
        let speechAudio: String?
        let speechText: String?
        let debugPrompt: String?

        enum CodingKeys: String, CodingKey {
            case progress, status
            case mistakeExplanation = "mistake_explanation"
            case stepsCompleted = "steps_completed"
            case speechAudio = "speech_audio"
            case speechText = "speech_text"
            case debugPrompt = "debug_prompt"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            progress = try container.decode(Double.self, forKey: .progress)
            status = try container.decode(String.self, forKey: .status)
            mistakeExplanation = try container.decodeIfPresent(String.self, forKey: .mistakeExplanation)
            stepsCompleted = try container.decodeIfPresent(Int.self, forKey: .stepsCompleted) ?? 1
            speechAudio = try container.decodeIfPresent(String.self, forKey: .speechAudio)
            speechText = try container.decodeIfPresent(String.self, forKey: .speechText)
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
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(EvalResponse.self, from: data)
    }

    // MARK: - TTS Helper

    /// Public wrapper for TTS — called by CanvasViewModel when polling detects new speech
    func speakText(_ phrase: String) async {
        await speakPhrase(phrase)
    }

    private func speakPhrase(_ phrase: String) async {
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
        playAudio(audioData)
    }

    // MARK: - Chat

    var isSendingChat: Bool = false
    private var chatTask: Task<Void, Never>?

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
        chatMessages.append(TutorChatMessage(role: .student, latex: trimmed, timestamp: Date()))
        isSendingChat = true

        chatTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.callChatServer(
                    message: trimmed, documentId: documentId, questionNumber: questionNumber,
                    partLabel: partLabel, stepIndex: stepIndex,
                    studentLatex: studentLatex, studentImage: studentImage
                )
                self.chatMessages.append(TutorChatMessage(role: .answer, latex: response.reply, timestamp: Date()))
                if self.voiceEnabled, let audioBase64 = response.speechAudio,
                   let audioData = Data(base64Encoded: audioBase64) {
                    self.playAudio(audioData)
                }
                if response.answerKeyUpdated { self.onAnswerKeyUpdated?() }
            } catch {
                self.chatMessages.append(TutorChatMessage(
                    role: .answer, latex: "Couldn't reach the tutor right now. Try again in a moment.", timestamp: Date()
                ))
            }
            self.isSendingChat = false
        }
    }

    private struct ChatRequest: Encodable {
        let documentId: String
        let questionNumber: Int
        let partLabel: String?
        let stepIndex: Int
        let studentLatex: String
        let userMessage: String
        let history: [HistoryEntry]
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
        message: String, documentId: String, questionNumber: Int,
        partLabel: String?, stepIndex: Int, studentLatex: String,
        studentImage: String? = nil
    ) async throws -> ChatResponse {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/tutor-chat") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session
        let historyMessages = chatMessages.suffix(10).map { msg in
            HistoryEntry(role: msg.role.rawValue, text: msg.latex)
        }

        let body = ChatRequest(
            documentId: documentId, questionNumber: questionNumber,
            partLabel: partLabel, stepIndex: stepIndex,
            studentLatex: studentLatex, userMessage: message,
            history: historyMessages, studentImage: studentImage
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
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
                Task { @MainActor in self?.isTutorSpeaking = false }
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

    // MARK: - Simulation Support

    /// Appends messages received from the server (via sim polling) that aren't already present.
    func appendRemoteMessages(_ messages: [TutorChatMessage]) {
        for msg in messages {
            if !chatMessages.contains(where: { $0.latex == msg.latex && $0.role == msg.role }) {
                chatMessages.append(msg)
            }
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
