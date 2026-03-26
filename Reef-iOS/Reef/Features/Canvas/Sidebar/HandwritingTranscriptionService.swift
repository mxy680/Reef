import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Sends PKDrawing strokes to the server for Mathpix real-time transcription.
/// Clusters strokes by Y-position (≤30 per cluster) and transcribes in parallel.
/// Only re-transcribes clusters that changed since the last poll.
@Observable
@MainActor
final class HandwritingTranscriptionService {
    var latexResult: String = ""      // KaTeX-sanitized display version
    var rawLatexResult: String = ""    // Raw Mathpix output for LLM eval
    var isTranscribing: Bool = false
    var errorMessage: String?

    /// Current cluster bounding boxes for debug visualization (in canvas points).
    var debugClusterBounds: [CGRect] = []

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

    /// Per-cluster transcription cache: cluster hash → (display, raw) LaTeX
    private var clusterCache: [Int: (display: String, raw: String)] = [:]

    private static let sessionTTL: TimeInterval = 300
    private static let pollInterval: Duration = .milliseconds(400)
    private static let maxStrokesPerCluster = 30
    private static let clusterYGap: CGFloat = 40  // pt gap to split clusters

    // MARK: - Polling

    var currentDrawing: PKDrawing?
    var currentRegions: [PartRegion]?
    var screenScale: CGFloat = 2.0

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

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollForChanges() {
        guard let drawing = currentDrawing else { return }

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
                rawLatexResult = ""
                clusterCache.removeAll()
            }
            lastStrokeCount = 0
            lastStrokeBoundsHash = 0
            return
        }

        let boundsHash = relevantStrokes.enumerated().reduce(0) { hash, pair in
            let (i, stroke) = pair
            let b = stroke.renderBounds
            return hash &+ (b.origin.x.hashValue &* (i &+ 1))
                        &+ (b.origin.y.hashValue &* (i &+ 2))
                        &+ (b.size.width.hashValue &* (i &+ 3))
                        &+ (b.size.height.hashValue &* (i &+ 4))
        }

        guard relevantStrokes.count != lastStrokeCount || boundsHash != lastStrokeBoundsHash else {
            return
        }

        lastStrokeCount = relevantStrokes.count
        lastStrokeBoundsHash = boundsHash

        generation += 1
        Task { [weak self, relevantStrokes] in
            await self?.performTranscription(strokes: relevantStrokes)
        }
    }

    // MARK: - Clustering

    private struct StrokeCluster {
        let strokes: [PKStroke]
        let hash: Int

        init(strokes: [PKStroke]) {
            self.strokes = strokes
            self.hash = strokes.enumerated().reduce(0) { h, pair in
                let (i, s) = pair
                let b = s.renderBounds
                return h &+ (b.origin.x.hashValue &* (i &+ 1))
                         &+ (b.midY.hashValue &* (i &+ 2))
                         &+ (b.size.width.hashValue &* (i &+ 3))
            }
        }
    }

    /// Cluster strokes by Y-position. Each cluster ≤ maxStrokesPerCluster.
    private func clusterStrokes(_ strokes: [PKStroke]) -> [StrokeCluster] {
        guard !strokes.isEmpty else { return [] }

        // Sort by vertical midpoint
        let sorted = strokes.sorted { $0.renderBounds.midY < $1.renderBounds.midY }

        var clusters: [[PKStroke]] = [[sorted[0]]]

        for i in 1..<sorted.count {
            let stroke = sorted[i]
            let prevMidY = sorted[i - 1].renderBounds.midY
            let curMidY = stroke.renderBounds.midY
            let gap = curMidY - prevMidY

            // Start new cluster if Y-gap exceeds threshold or current cluster is full
            if gap > Self.clusterYGap || clusters[clusters.count - 1].count >= Self.maxStrokesPerCluster {
                clusters.append([stroke])
            } else {
                clusters[clusters.count - 1].append(stroke)
            }
        }

        // Split any remaining oversized clusters
        var result: [StrokeCluster] = []
        for group in clusters {
            if group.count <= Self.maxStrokesPerCluster {
                result.append(StrokeCluster(strokes: group))
            } else {
                for chunk in stride(from: 0, to: group.count, by: Self.maxStrokesPerCluster) {
                    let end = min(chunk + Self.maxStrokesPerCluster, group.count)
                    result.append(StrokeCluster(strokes: Array(group[chunk..<end])))
                }
            }
        }

        return result
    }

    // MARK: - Clustered Transcription

    private func performTranscription(strokes: [PKStroke]) async {
        let myGeneration = generation

        isTranscribing = true
        errorMessage = nil

        // Debug: single bounding box for all strokes
        debugClusterBounds = [strokes.reduce(CGRect.null) { $0.union($1.renderBounds) }]

        // Extract payloads on main actor (PKStroke is not Sendable)
        let payloads = extractPayloads(from: strokes)

        // Transcribe all strokes in one call
        let result = await transcribePayloads(payloads)

        guard generation == myGeneration else { return }

        let display = result?.display ?? ""
        let raw = result?.raw ?? ""

        let oldLatex = latexResult
        latexResult = display
        rawLatexResult = raw
        if display != oldLatex, !display.isEmpty {
            onLatexChanged?(display)
        }

        isTranscribing = false
    }

    /// Extract and normalize stroke payloads on the main actor (PKStroke is not Sendable).
    private func extractPayloads(from strokes: [PKStroke]) -> [StrokePayload] {
        var allPoints: [(x: Double, y: Double)] = []
        let payloads: [StrokePayload] = strokes.map { stroke in
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

        let minX = allPoints.map(\.x).min() ?? 0
        let minY = allPoints.map(\.y).min() ?? 0
        return payloads.map { payload in
            StrokePayload(
                x: payload.x.map { $0 - minX },
                y: payload.y.map { $0 - minY }
            )
        }
    }

    /// Transcribe pre-extracted payloads (≤30 strokes). Returns (display, raw).
    private func transcribePayloads(_ normalized: [StrokePayload]) async -> (display: String, raw: String)? {
        do {
            let (token, sid) = try await ensureSession()

            guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                  let url = URL(string: "\(serverURL)/ai/transcribe-strokes") else {
                return nil
            }

            let authSession = try await supabase.auth.session

            let body = TranscribeStrokesRequest(
                strokes: normalized,
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

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(TranscribeStrokesResponse.self, from: data)
            return (display: result.latex, raw: result.raw_latex ?? result.latex)
        } catch {
            print("[Transcription] Cluster error: \(error)")
            return nil
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
        clusterCache.removeAll()
    }

    func reset() {
        stopPolling()
        resetSession()
        latexResult = ""
        rawLatexResult = ""
        debugClusterBounds = []
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
    let raw_latex: String?
    let session_id: String?
}
