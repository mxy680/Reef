//
//  TranscriptionService.swift
//  Reef
//
//  Sends pen strokes to Reef-Server for Mathpix transcription
//  and caches the latest LaTeX per subquestion.
//

import Foundation

@Observable
@MainActor
final class TranscriptionService {
    /// Latest LaTeX result per subquestion key (e.g. "0-a", "1-b")
    private(set) var transcriptions: [String: String] = [:]

    /// Currently active subquestion key
    private(set) var activeKey: String?

    /// In-flight request — cancelled when a new stroke arrives
    private var inflightTask: Task<Void, Never>?

    func transcribe(
        questionIndex: Int,
        partLabel: String,
        strokes: [[(x: Double, y: Double)]]
    ) {
        let key = "\(questionIndex)-\(partLabel)"
        activeKey = key

        // Cancel stale request
        inflightTask?.cancel()

        guard !strokes.isEmpty else { return }

        inflightTask = Task {
            do {
                let body = TranscribeRequest(
                    strokes: strokes.map { points in
                        StrokePayload(
                            x: points.map(\.x),
                            y: points.map(\.y)
                        )
                    }
                )
                let response: TranscribeResponse = try await ReefAPI.shared.request(
                    "POST",
                    path: "/ai/transcribe-strokes",
                    body: body
                )
                guard !Task.isCancelled else { return }
                transcriptions[key] = response.latex
            } catch {
                if !Task.isCancelled {
                    print("[TranscriptionService] Error: \(error)")
                }
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
}

private struct TranscribeResponse: Decodable {
    let latex: String
}
