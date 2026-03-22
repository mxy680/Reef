import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Sends PKDrawing strokes to the server for Mathpix real-time transcription.
/// Uses Mathpix session-based Strokes API — sends on every new stroke.
/// Sessions last 5 minutes; a new session is created automatically when expired.
/// Only sends strokes within the active question region.
@Observable
@MainActor
final class HandwritingTranscriptionService {
    var latexResult: String = ""
    var isTranscribing: Bool = false
    var errorMessage: String?

    /// Called when latexResult changes to a new non-empty value.
    var onLatexChanged: ((String) -> Void)?

    private(set) var sessionId: String?
    private(set) var sessionStart: Date?
    var sessionSecondsRemaining: Int = 0
    private(set) var appToken: String?
    private(set) var expiresAt: Date?
    private var generation: Int = 0
    private var transcribeTask: Task<Void, Never>?

    private static let sessionTTL: TimeInterval = 300

    // MARK: - Session Management

    private func ensureSession() async throws -> (token: String, sessionId: String) {
        if let token = appToken, let sid = sessionId, let expires = expiresAt, Date() < expires {
            return (token, sid)
        }

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
        self.expiresAt = Date().addingTimeInterval(Self.sessionTTL)
        self.sessionSecondsRemaining = 300

        return (result.app_token, result.strokes_session_id)
    }

    // MARK: - Transcription

    /// Called on every drawing change. Filters strokes to the active question region.
    /// - Parameters:
    ///   - drawing: The full page drawing
    ///   - activeRegions: The regions for the active question on the current local page (nil = send all strokes)
    ///   - screenScale: The screen scale factor to convert renderBounds to PDF points
    func onDrawingChanged(drawing: PKDrawing, activeRegions: [PartRegion]?, screenScale: CGFloat = 2.0) {
        // Filter strokes to active question region
        let relevantStrokes: [PKStroke]
        if let regions = activeRegions, !regions.isEmpty {
            relevantStrokes = drawing.strokes.filter { stroke in
                let midY = Double(stroke.renderBounds.midY) / Double(screenScale)
                return regions.contains { region in
                    midY >= region.yStart && midY <= region.yEnd
                }
            }
        } else {
            relevantStrokes = drawing.strokes
        }

        guard !relevantStrokes.isEmpty else {
            latexResult = ""
            return
        }

        transcribeTask?.cancel()

        // Extract stroke coordinates and normalize to (0,0)
        var allPoints: [(x: Double, y: Double)] = []
        let strokePayloads: [StrokePayload] = relevantStrokes.map { stroke in
            var xs: [Double] = []
            var ys: [Double] = []
            for i in 0..<stroke.path.count {
                let pt = stroke.path[i].location
                xs.append(Double(pt.x))
                ys.append(Double(pt.y))
                allPoints.append((Double(pt.x), Double(pt.y)))
            }
            return StrokePayload(x: xs, y: ys)
        }

        // Normalize: translate so bounding box starts at (0,0)
        let minX = allPoints.map(\.x).min() ?? 0
        let minY = allPoints.map(\.y).min() ?? 0
        let normalizedPayloads = strokePayloads.map { payload in
            StrokePayload(
                x: payload.x.map { $0 - minX },
                y: payload.y.map { $0 - minY }
            )
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
                    strokes: normalizedPayloads,
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
                let oldLatex = self.latexResult
                self.latexResult = result.latex
                if result.latex != oldLatex, !result.latex.isEmpty {
                    self.onLatexChanged?(result.latex)
                }
            } catch {
                guard !Task.isCancelled, self.generation == myGeneration else { return }
                self.errorMessage = "Transcription failed"
                print("[Transcription] Error: \(error)")
            }

            self.isTranscribing = false
        }
    }

    // MARK: - Timer

    func tickTimer() {
        guard let start = sessionStart else {
            sessionSecondsRemaining = 0
            return
        }
        let elapsed = Int(Date().timeIntervalSince(start))
        sessionSecondsRemaining = max(0, 300 - elapsed)
        if sessionSecondsRemaining == 0 {
            sessionId = nil
            sessionStart = nil
            appToken = nil
            expiresAt = nil
        }
    }

    // MARK: - Reset

    /// Reset session only (on question change) — clears Mathpix session so new strokes
    /// aren't mixed with previous question's accumulated data.
    func resetSession() {
        transcribeTask?.cancel()
        generation += 1
        sessionId = nil
        sessionStart = nil
        sessionSecondsRemaining = 0
        appToken = nil
        expiresAt = nil
        isTranscribing = false
        errorMessage = nil
    }

    /// Full reset (on sidebar close).
    func reset() {
        resetSession()
        latexResult = ""
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
