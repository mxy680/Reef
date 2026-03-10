//
//  TranscriptionService.swift
//  Reef
//
//  Sends pen strokes to Reef-Server for Mathpix transcription
//  and caches the latest LaTeX per subquestion.
//  Manages Mathpix sessions (up to 300s) per question for better recognition.
//

import Foundation

@Observable
@MainActor
final class TranscriptionService {
    /// Latest LaTeX result per subquestion key (e.g. "0-a", "1-b")
    private(set) var transcriptions: [String: String] = [:]

    /// Currently active subquestion key
    private(set) var activeKey: String?

    /// Generation counter — incremented on each transcribe call.
    /// Only the response matching the latest generation is applied.
    private var generation: Int = 0

    // MARK: - Session Management

    /// Active Mathpix session ID per question index
    private var sessionIds: [Int: String] = [:]

    /// When each session was created
    private var sessionStartTimes: [Int: Date] = [:]

    /// Sessions expire after 300 seconds
    private static let sessionTTL: TimeInterval = 300

    func transcribe(
        questionIndex: Int,
        partLabel: String,
        strokes: [[(x: Double, y: Double)]]
    ) {
        let key = "\(questionIndex)-\(partLabel)"
        activeKey = key

        generation += 1
        let myGeneration = generation

        guard !strokes.isEmpty else { return }

        // Check if session has expired
        if let startTime = sessionStartTimes[questionIndex],
           Date().timeIntervalSince(startTime) >= Self.sessionTTL {
            sessionIds.removeValue(forKey: questionIndex)
            sessionStartTimes.removeValue(forKey: questionIndex)
        }

        let sessionId = sessionIds[questionIndex]
        let isNewSession = sessionId == nil

        Task { [weak self] in
            do {
                let body = TranscribeRequest(
                    strokes: strokes.map { points in
                        StrokePayload(
                            x: points.map(\.x),
                            y: points.map(\.y)
                        )
                    },
                    session_id: sessionId
                )
                let response: TranscribeResponse = try await ReefAPI.shared.request(
                    "POST",
                    path: "/ai/transcribe-strokes",
                    body: body
                )
                guard let self, self.generation == myGeneration else { return }
                self.transcriptions[key] = response.latex
                print("[TranscriptionService] Q\(questionIndex+1)(\(partLabel)): \(response.latex)")

                // Store session ID from first response
                if isNewSession, let newSessionId = response.session_id {
                    self.sessionIds[questionIndex] = newSessionId
                    self.sessionStartTimes[questionIndex] = Date()
                }
            } catch {
                print("[TranscriptionService] Error: \(error)")
            }
        }
    }
}

// MARK: - Codable Models

private struct StrokePayload: Encodable {
    let x: [Double]
    let y: [Double]
}

private struct TranscribeRequest: Encodable {
    let strokes: [StrokePayload]
    let session_id: String?
}

private struct TranscribeResponse: Decodable {
    let latex: String
    let session_id: String?
}
