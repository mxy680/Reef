import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Sends PKDrawing strokes to the server for Mathpix real-time transcription.
/// Uses Mathpix session-based Strokes API — sends on every new stroke, no debounce.
/// Sessions last 5 minutes; a new session is created automatically when expired.
@Observable
@MainActor
final class HandwritingTranscriptionService {
    var latexResult: String = ""
    var isTranscribing: Bool = false
    var errorMessage: String?

    private(set) var sessionId: String?
    private(set) var sessionStart: Date?
    var sessionSecondsRemaining: Int = 0
    private(set) var appToken: String?
    private(set) var expiresAt: Date?
    private var generation: Int = 0
    private var transcribeTask: Task<Void, Never>?

    private static let sessionTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Session Management

    private func ensureSession() async throws -> (token: String, sessionId: String) {
        // Reuse existing valid session
        if let token = appToken, let sid = sessionId, let expires = expiresAt, Date() < expires {
            return (token, sid)
        }

        // Create new session via server proxy
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/strokes-session") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct SessionResponse: Decodable {
            let app_token: String
            let strokes_session_id: String
            let expires_at: Int
        }

        let result = try JSONDecoder().decode(SessionResponse.self, from: data)
        self.appToken = result.app_token
        self.sessionId = result.strokes_session_id
        self.sessionStart = Date()
        // Use 300s TTL from now for simplicity
        self.expiresAt = Date().addingTimeInterval(Self.sessionTTL)
        self.sessionSecondsRemaining = 300

        return (result.app_token, result.strokes_session_id)
    }

    // MARK: - Transcription

    /// Called on every drawing change — sends all strokes immediately.
    func onDrawingChanged(drawing: PKDrawing) {
        guard !drawing.strokes.isEmpty else {
            latexResult = ""
            return
        }

        // Cancel previous in-flight request
        transcribeTask?.cancel()

        // Extract stroke coordinates from PKDrawing
        let strokePayloads: [StrokePayload] = drawing.strokes.map { stroke in
            var xs: [Double] = []
            var ys: [Double] = []
            for i in 0..<stroke.path.count {
                let pt = stroke.path[i].location
                xs.append(Double(pt.x))
                ys.append(Double(pt.y))
            }
            return StrokePayload(x: xs, y: ys)
        }

        generation += 1
        let myGeneration = generation

        transcribeTask = Task { [weak self] in
            guard let self else { return }
            self.isTranscribing = true
            self.errorMessage = nil

            do {
                let (token, sid) = try await ensureSession()

                guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                      let url = URL(string: "\(serverURL)/ai/transcribe-strokes") else {
                    self.errorMessage = "Server not configured"
                    self.isTranscribing = false
                    return
                }

                let authSession = try await supabase.auth.session

                let body = TranscribeStrokesRequest(
                    strokes: strokePayloads,
                    session_id: sid,
                    app_token: token
                )

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONEncoder().encode(body)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let result = try JSONDecoder().decode(TranscribeStrokesResponse.self, from: data)

                guard self.generation == myGeneration else { return }

                self.latexResult = result.latex
            } catch {
                guard !Task.isCancelled, self.generation == myGeneration else { return }
                self.errorMessage = "Transcription failed"
                print("[Transcription] Error: \(error)")
            }

            self.isTranscribing = false
        }
    }

    // MARK: - Timer

    /// Call every second from the view to update the countdown.
    func tickTimer() {
        guard let start = sessionStart else {
            sessionSecondsRemaining = 0
            return
        }
        let elapsed = Int(Date().timeIntervalSince(start))
        sessionSecondsRemaining = max(0, 300 - elapsed)
        if sessionSecondsRemaining == 0 {
            // Session expired — clear so next stroke creates a new one
            sessionId = nil
            sessionStart = nil
            appToken = nil
            expiresAt = nil
        }
    }

    // MARK: - Reset

    func reset() {
        transcribeTask?.cancel()
        latexResult = ""
        errorMessage = nil
        isTranscribing = false
        sessionId = nil
        sessionStart = nil
        sessionSecondsRemaining = 0
        appToken = nil
        expiresAt = nil
    }
}

// MARK: - Codable Models

private struct StrokePayload: Encodable {
    let x: [Double]
    let y: [Double]
}

private struct TranscribeStrokesRequest: Encodable {
    let strokes: [StrokePayload]
    let session_id: String?
    let app_token: String?
}

private struct TranscribeStrokesResponse: Decodable {
    let latex: String
    let session_id: String?
}
