import SwiftUI
@preconcurrency import Supabase

/// A single message in the tutor chat feed.
struct TutorChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let latex: String
    let timestamp: Date

    enum Role {
        case student   // student's transcribed work
        case tutor     // tutor feedback (mistake, on track, completed)
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
        figureURLs: [String] = []
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

            do {
                let response = try await self.callServer(
                    latex: latex,
                    documentId: documentId,
                    questionNumber: questionNumber,
                    partLabel: partLabel,
                    stepIndex: stepIndex,
                    figureURLs: figureURLs
                )

                guard self.generation == myGeneration else { return }

                self.stepProgress = response.progress
                self.status = response.status
                self.mistakeExplanation = response.mistakeExplanation
                self.lastEvaluatedLatex = latex

                // Add chat messages for mistakes
                if let mistake = response.mistakeExplanation, response.status == "mistake" {
                    let now = Date()
                    // Student message: what they wrote
                    self.chatMessages.append(TutorChatMessage(
                        role: .student, latex: latex, timestamp: now
                    ))
                    // Tutor message: the feedback
                    self.chatMessages.append(TutorChatMessage(
                        role: .tutor, latex: mistake, timestamp: now
                    ))
                }

                if response.status == "completed" {
                    self.onStepCompleted?()
                }
            } catch {
                guard !Task.isCancelled, self.generation == myGeneration else { return }
                print("[TutorEvalSvc] Evaluation failed: \(error)")
            }

            self.isEvaluating = false
            self.evaluateTask = nil
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

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case questionNumber = "question_number"
            case partLabel = "part_label"
            case stepIndex = "step_index"
            case studentLatex = "student_latex"
            case figureUrls = "figure_urls"
        }
    }

    private func callServer(
        latex: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        figureURLs: [String]
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
            figureUrls: figureURLs
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
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
        studentLatex: String
    ) {
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
                let reply = try await self.callChatServer(
                    message: trimmed,
                    documentId: documentId,
                    questionNumber: questionNumber,
                    partLabel: partLabel,
                    stepIndex: stepIndex,
                    studentLatex: studentLatex
                )
                self.chatMessages.append(TutorChatMessage(
                    role: .tutor, latex: reply, timestamp: Date()
                ))
            } catch {
                self.chatMessages.append(TutorChatMessage(
                    role: .tutor, latex: "Sorry, couldn't get a response. Try again.", timestamp: Date()
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

        enum CodingKeys: String, CodingKey {
            case documentId = "document_id"
            case questionNumber = "question_number"
            case partLabel = "part_label"
            case stepIndex = "step_index"
            case studentLatex = "student_latex"
            case userMessage = "user_message"
        }
    }

    private struct ChatResponse: Decodable {
        let reply: String
    }

    private func callChatServer(
        message: String,
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        stepIndex: Int,
        studentLatex: String
    ) async throws -> String {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/tutor-chat") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session

        let body = ChatRequest(
            documentId: documentId,
            questionNumber: questionNumber,
            partLabel: partLabel,
            stepIndex: stepIndex,
            studentLatex: studentLatex,
            userMessage: message
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChatResponse.self, from: data).reply
    }
}
