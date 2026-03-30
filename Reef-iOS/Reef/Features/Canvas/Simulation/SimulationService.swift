#if DEBUG
import SwiftUI
@preconcurrency import Supabase

// MARK: - Simulation Service

/// Manages the student simulation lifecycle.
///
/// Flow:
/// 1. `start(...)` → POST /ai/simulation/start → server returns strokes → render
/// 2. Transcription fires → eval fires → `onStepCompleted` triggers `continueAfterEval(...)`
/// 3. `continueAfterEval(...)` → POST /ai/simulation/continue → server returns more strokes → repeat
/// 4. `stop(...)` → POST /ai/simulation/stop → clears state
@Observable
@MainActor
final class SimulationService {

    // MARK: - Public State

    var isSimulating = false
    var currentStep = 0
    var totalSteps = 0
    var lastReasoning = ""

    // MARK: - Private

    private var serverURL: String {
        Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String ?? ""
    }

    // MARK: - Start

    func start(
        documentId: String,
        questionNumber: Int,
        partLabel: String?,
        drawingManager: CanvasDrawingManager,
        pageIndex: Int,
        targetRect: CGRect,
        personality: String = "mistake_prone"
    ) async {
        guard !isSimulating else { return }
        isSimulating = true
        currentStep = 0
        totalSteps = 0
        lastReasoning = ""

        guard let token = try? await supabase.auth.session.accessToken else {
            isSimulating = false
            return
        }

        let body: [String: Any] = [
            "document_id": documentId,
            "question_number": questionNumber,
            "part_label": partLabel ?? "a",
            "personality": personality,
        ]

        guard let url = URL(string: "\(serverURL)/ai/simulation/start") else {
            isSimulating = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            isSimulating = false
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            isSimulating = false
            return
        }

        await handleStrokesMessage(
            json,
            drawingManager: drawingManager,
            pageIndex: pageIndex,
            targetRect: targetRect
        )
    }

    // MARK: - Continue

    func continueAfterEval(
        documentId: String,
        tutorStatus: String,
        tutorFeedback: String?,
        stepIndex: Int,
        drawingManager: CanvasDrawingManager,
        pageIndex: Int,
        targetRect: CGRect
    ) async {
        guard isSimulating else { return }

        // Wait so the developer can observe the tutor feedback
        try? await Task.sleep(for: .seconds(2.5))
        guard isSimulating else { return }

        guard let token = try? await supabase.auth.session.accessToken else { return }

        let body: [String: Any] = [
            "document_id": documentId,
            "tutor_status": tutorStatus,
            "tutor_feedback": tutorFeedback ?? "",
            "step_index": stepIndex,
        ]

        guard let url = URL(string: "\(serverURL)/ai/simulation/continue") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Check for simulation_complete signal
        if let messageType = json["type"] as? String, messageType == "simulation_complete" {
            handleCompleteMessage()
            return
        }

        await handleStrokesMessage(
            json,
            drawingManager: drawingManager,
            pageIndex: pageIndex,
            targetRect: targetRect
        )
    }

    // MARK: - Stop

    func stop(documentId: String) async {
        isSimulating = false

        guard let token = try? await supabase.auth.session.accessToken,
              let url = URL(string: "\(serverURL)/ai/simulation/stop") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["document_id": documentId])
        request.timeoutInterval = 10

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Message Handling

    /// Handle a JSON payload containing stroke data from the server.
    func handleStrokesMessage(
        _ json: [String: Any],
        drawingManager: CanvasDrawingManager,
        pageIndex: Int,
        targetRect: CGRect
    ) async {
        guard let strokesRaw = json["strokes"] as? [[String: [Double]]] else { return }

        if let step = json["step_index"] as? Int { currentStep = step }
        if let reasoning = json["reasoning"] as? String { lastReasoning = reasoning }
        if let latex = json["latex"] as? String {
            print("[simulation] Step \(currentStep): \(latex)")
        }

        let pkStrokes = SimulationStrokeRenderer.buildStrokes(from: strokesRaw, targetRect: targetRect)
        await SimulationStrokeRenderer.animateStrokes(
            pkStrokes,
            onto: drawingManager,
            pageIndex: pageIndex
        )
    }

    func handleCompleteMessage() {
        isSimulating = false
        print("[simulation] Complete!")
    }
}
#endif
