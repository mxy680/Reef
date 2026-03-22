import SwiftUI
import AVFoundation
@preconcurrency import Supabase

/// A single message in the tutor chat feed.
struct TutorChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let latex: String
    let timestamp: Date

    enum Role: String {
        case student        // student's transcribed work or typed question
        case error          // tutor detected a mistake
        case reinforcement  // tutor celebrates step completion
        case answer         // tutor responds to a user question
    }
}

/// Evaluates student handwriting against the answer key in real time.
/// Debounces requests by 1.5s and discards stale responses via a generation counter.
@Observable
@MainActor
final class TutorEvaluationService {
    // MARK: - Public State

    var stepProgress: Double = 0.0
    var status: String = "idle"
    var mistakeExplanation: String?
    var isEvaluating: Bool = false
    var chatMessages: [TutorChatMessage] = []

    /// Fires when the model marks the current step as "completed".
    var onStepCompleted: (() -> Void)?

    /// Reinforcement text for the current step (from answer key).
    var pendingReinforcement: String?

    // MARK: - Private

    private var generation: Int = 0
    private var evaluateTask: Task<Void, Never>?
    private var lastEvaluatedLatex: String = ""

    private static let debounceInterval: Duration = .milliseconds(1500)

    // MARK: - Evaluate

    /// Trigger an evaluation. Debounces by 1.5s. Skips if latex is unchanged.
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

                self.stepProgress = response.progress
                self.status = response.status
                self.mistakeExplanation = response.mistakeExplanation
                self.lastEvaluatedLatex = latex

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

                // Step completed — show reinforcement then advance
                if response.status == "completed" {
                    if let reinforcement = self.pendingReinforcement, !reinforcement.isEmpty {
                        self.chatMessages.append(TutorChatMessage(
                            role: .reinforcement, latex: reinforcement, timestamp: Date()
                        ))
                    }
                    self.onStepCompleted?()
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
        mistakeExplanation = nil
        isEvaluating = false
        lastEvaluatedLatex = ""
    }

    /// Full reset (tutor mode toggled off or question changed).
    func reset() {
        resetForNextStep()
        chatMessages.removeAll()
    }

    // MARK: - Network

    private struct EvalResponse: Decodable {
        let progress: Double
        let status: String
        let mistakeExplanation: String?

        enum CodingKeys: String, CodingKey {
            case progress, status
            case mistakeExplanation = "mistake_explanation"
        }
    }

    private struct EvalRequest: Encodable {
        let documentId: String
        let questionNumber: Int
        let partLabel: String?
        let stepIndex: Int
        let studentLatex: String
        let figureUrls: [String]
        let studentImage: String?

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case questionNumber = "question_number"
            case partLabel = "part_label"
            case stepIndex = "step_index"
            case studentLatex = "student_latex"
            case figureUrls = "figure_urls"
            case studentImage = "student_image"
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

        let body = EvalRequest(
            documentId: documentId,
            questionNumber: questionNumber,
            partLabel: partLabel,
            stepIndex: stepIndex,
            studentLatex: latex,
            figureUrls: figureURLs,
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

        return try JSONDecoder().decode(EvalResponse.self, from: data)
    }

    // MARK: - Chat

    var isSendingChat: Bool = false

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

        Task { [weak self] in
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
                // Play TTS audio if available
                if let audioBase64 = response.speechAudio,
                   let audioData = Data(base64Encoded: audioBase64) {
                    self.playAudio(audioData)
                }
            } catch {
                self.chatMessages.append(TutorChatMessage(
                    role: .answer, latex: "Failed: \(error.localizedDescription)", timestamp: Date()
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

        enum CodingKeys: String, CodingKey {
            case reply
            case speechAudio = "speech_audio"
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

    private var audioPlayer: AVAudioPlayer?

    private func playAudio(_ data: Data) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("[TutorEval] Audio playback failed: \(error)")
        }
    }
}
