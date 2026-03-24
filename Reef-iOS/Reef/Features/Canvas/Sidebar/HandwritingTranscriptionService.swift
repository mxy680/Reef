import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Sends PKDrawing strokes to the server for Mathpix real-time transcription.
/// Polls every 400ms for drawing changes instead of reacting to each stroke.
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
    private var pollingTask: Task<Void, Never>?
    private var lastStrokeCount: Int = 0
    private var lastStrokeBoundsHash: Int = 0

    private static let sessionTTL: TimeInterval = 300
    private static let pollInterval: Duration = .milliseconds(400)

    // MARK: - Polling

    /// The current drawing and region context, updated by CanvasView on every drawing change.
    var currentDrawing: PKDrawing?
    var currentRegions: [PartRegion]?
    var screenScale: CGFloat = 2.0

    /// Start polling for drawing changes every 400ms.
    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard let self, !Task.isCancelled else { return }
                self.pollForChanges()
            }
        }
    }

    /// Stop polling.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Check if drawing changed since last poll and trigger transcription if so.
    private func pollForChanges() {
        guard let drawing = currentDrawing else { return }

        // Filter strokes to active question region
        let relevantStrokes: [PKStroke]
        if let regions = currentRegions, !regions.isEmpty {
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
            if !latexResult.isEmpty {
                latexResult = ""
            }
            lastStrokeCount = 0
            lastStrokeBoundsHash = 0
            return
        }

        // Quick change detection: stroke count + bounds hash
        let boundsHash = relevantStrokes.reduce(0) { hash, stroke in
            hash ^ stroke.renderBounds.origin.x.hashValue ^ stroke.renderBounds.origin.y.hashValue
                 ^ stroke.renderBounds.size.width.hashValue ^ stroke.renderBounds.size.height.hashValue
        }

        guard relevantStrokes.count != lastStrokeCount || boundsHash != lastStrokeBoundsHash else {
            return // No change
        }

        lastStrokeCount = relevantStrokes.count
        lastStrokeBoundsHash = boundsHash

        // Transcribe
        generation += 1
        Task { [weak self, relevantStrokes] in
            await self?.performTranscription(strokes: relevantStrokes)
        }
    }

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

    private func performTranscription(strokes relevantStrokes: [PKStroke]) async {
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

        let myGeneration = generation

        isTranscribing = true
        errorMessage = nil

        do {
            let (token, sid) = try await ensureSession()

            guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                  let url = URL(string: "\(serverURL)/ai/transcribe-strokes") else {
                errorMessage = "Server not configured"
                isTranscribing = false
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

            guard generation == myGeneration else { return }
            let oldLatex = latexResult
            latexResult = result.latex
            if result.latex != oldLatex, !result.latex.isEmpty {
                onLatexChanged?(result.latex)
            }
        } catch {
            guard !Task.isCancelled, generation == myGeneration else { return }
            errorMessage = "Transcription failed"
            print("[Transcription] Error: \(error)")
        }

        isTranscribing = false
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
        generation += 1
        sessionId = nil
        sessionStart = nil
        sessionSecondsRemaining = 0
        appToken = nil
        expiresAt = nil
        isTranscribing = false
        errorMessage = nil
        lastStrokeCount = 0
        lastStrokeBoundsHash = 0
    }

    /// Full reset (on sidebar close).
    func reset() {
        stopPolling()
        resetSession()
        latexResult = ""
        currentDrawing = nil
        currentRegions = nil
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
