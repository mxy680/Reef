import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Sends PKDrawing strokes to the server for Mathpix real-time transcription.
/// Clusters strokes by Y-position (≤30 per cluster) and transcribes in parallel.
/// Only re-transcribes clusters that changed since the last poll.
@Observable
@MainActor
final class HandwritingTranscriptionService {
    var latexResult: String = ""
    var rawLatexResult: String = ""
    var isTranscribing: Bool = false
    var errorMessage: String?

    /// Set by CanvasViewModel — used to write transcription to Supabase
    var documentId: String?
    var questionLabel: String?

    /// Called when latexResult changes to a new non-empty value.
    var onLatexChanged: ((String) -> Void)?

    private(set) var sessionId: String?
    private(set) var sessionStart: Date?
    var sessionSecondsRemaining: Int = 0
    private var appToken: String?
    private(set) var expiresAt: Date?
    private var generation: Int = 0
    private(set) var pollingTask: Task<Void, Never>?
    private let chunkCache = ChunkedTranscriptionCache()

    private static let sessionTTL: TimeInterval = 300
    private static let pollInterval: Duration = .milliseconds(400)

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

    private var pollLogCounter = 0
    private func pollForChanges() {
        pollLogCounter += 1
        guard let drawing = currentDrawing else {
            if pollLogCounter % 25 == 0 { print("[hw-poll] no drawing set") }
            return
        }

        let relevantStrokes = drawing.strokes

        guard !relevantStrokes.isEmpty else {
            if !latexResult.isEmpty {
                latexResult = ""
                rawLatexResult = ""
                chunkCache.reset()
            }
            return
        }

        let (dirty, totalChunks) = chunkCache.computeDirtyChunks(strokes: relevantStrokes)
        chunkCache.pruneChunksAbove(totalChunks - 1)
        guard !dirty.isEmpty else {
            if pollLogCounter % 25 == 0 { print("[hw-poll] no change: \(relevantStrokes.count) strokes") }
            return
        }
        print("[hw-poll] CHANGED: dirty chunks \(dirty.sorted()), totalChunks=\(totalChunks), transcribing...")

        generation += 1
        Task { [weak self, generation] in
            await self?.performChunkedTranscription(
                strokes: relevantStrokes,
                dirtyChunks: dirty,
                totalChunks: totalChunks,
                myGeneration: generation
            )
        }
    }


    // MARK: - Chunked Transcription

    private func performChunkedTranscription(
        strokes: [PKStroke],
        dirtyChunks: Set<Int>,
        totalChunks: Int,
        myGeneration: Int
    ) async {
        isTranscribing = true
        errorMessage = nil

        // Extract payloads for each dirty chunk on the main actor before spawning tasks
        // (PKStroke is not Sendable and cannot cross actor boundaries)
        struct ChunkWork: Sendable {
            let index: Int
            let fingerprint: Int
            let payloads: [StrokePayload]
        }

        let chunkWork: [ChunkWork] = dirtyChunks.sorted().compactMap { chunkIndex in
            let start = chunkIndex * ChunkedTranscriptionCache.chunkSize
            let end = min(start + ChunkedTranscriptionCache.chunkSize, strokes.count)
            let fp = chunkCache.fingerprint(for: strokes[start..<end])
            let payloads = extractPayloads(from: Array(strokes[start..<end]))
            return ChunkWork(index: chunkIndex, fingerprint: fp, payloads: payloads)
        }

        // Transcribe dirty chunks in parallel using only Sendable data
        await withTaskGroup(of: (Int, Int, String, String)?.self) { group in
            for work in chunkWork {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    guard let result = await self.transcribePayloads(work.payloads) else { return nil }
                    return (work.index, work.fingerprint, result.display, result.raw)
                }
            }

            for await result in group {
                guard generation == myGeneration else { return }
                if let (idx, fp, display, raw) = result {
                    chunkCache.store(chunkIndex: idx, fingerprint: fp, display: display, raw: raw)
                }
            }
        }

        guard generation == myGeneration else { return }

        let (display, raw) = chunkCache.concatenatedResult(totalChunks: totalChunks)

        let oldLatex = latexResult
        let oldRaw = rawLatexResult
        latexResult = display
        rawLatexResult = raw
        if (display != oldLatex || raw != oldRaw), !display.isEmpty {
            onLatexChanged?(display)
            writeToSupabase(display: display, raw: raw)
        }

        isTranscribing = false
    }

    /// Fire-and-forget upsert of transcription to Supabase student_work table.
    private func writeToSupabase(display: String, raw: String) {
        guard let docId = documentId, let qLabel = questionLabel else { return }
        Task {
            guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }
            let row: [String: String] = [
                "user_id": userId,
                "document_id": docId,
                "question_label": qLabel,
                "latex_display": display,
                "latex_raw": raw,
            ]
            try? await supabase
                .from("student_work")
                .upsert(row, onConflict: "user_id,document_id,question_label")
                .execute()
        }
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
        chunkCache.reset()
    }

    func reset() {
        stopPolling()
        resetSession()
        latexResult = ""
        rawLatexResult = ""
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
