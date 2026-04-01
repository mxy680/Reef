import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Syncs canvas strokes with Supabase via 1-second polling.
/// No Realtime, no WebSocket — just simple GET requests.
@Observable
@MainActor
final class CanvasSyncService {
    var onStrokesUpdated: ((CanvasStrokeRow) -> Void)?
    var onStrokesDeleted: (() -> Void)?

    /// Last known stroke hash per question — skip updates if unchanged
    private var lastStrokeHash: [String: Int] = [:]
    /// Timestamp of last local write — skip poll results within 2s
    private var lastLocalWriteTime: Date?

    private(set) var pollTimer: Timer?

    // MARK: - Start / Stop Polling

    func startPolling(documentId: String) {
        stopPolling()
        print("[Sync] Starting 1s poll for doc=\(documentId.prefix(12))")

        Task { @MainActor [weak self] in
            guard let self, let userId = try? await supabase.auth.session.user.id.uuidString else { return }

            // Seed poller hashes from existing rows so the first tick doesn't re-deliver them
            let selectCols = "question_label,page_index,strokes,updated_at"
            let rows: [CanvasStrokeRow] = (try? await supabase
                .from("canvas_strokes")
                .select(selectCols)
                .eq("user_id", value: userId)
                .eq("document_id", value: documentId)
                .execute().value) ?? []
            for row in rows {
                self.lastStrokeHash[row.questionLabel] = row.strokes.count
            }

            // Start the timer only after initial load is complete
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 {
                        return
                    }
                    await self.pollForChanges(documentId: documentId)
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        lastStrokeHash = [:]
    }

    // MARK: - Poll

    private func pollForChanges(documentId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let selectColumns = "question_label,page_index,strokes,updated_at"
        let rows: [CanvasStrokeRow] = (try? await supabase
            .from("canvas_strokes")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .execute().value) ?? []

        for row in rows {
            let hash = row.strokes.count
            if lastStrokeHash[row.questionLabel] != hash {
                lastStrokeHash[row.questionLabel] = hash
                // Only replace canvas if we haven't written locally recently —
                // external sources (simulation, another device) can push strokes.
                let isExternalWrite = lastLocalWriteTime == nil || Date().timeIntervalSince(lastLocalWriteTime!) > 5.0
                if isExternalWrite {
                    onStrokesUpdated?(row)
                }
            }
        }

        // If we had rows before but now don't, something was deleted
        if rows.isEmpty && !lastStrokeHash.isEmpty {
            lastStrokeHash = [:]
            onStrokesDeleted?()
        }
    }

    // MARK: - Write Strokes (UPSERT — one row per question)

    func writeStrokes(
        documentId: String,
        questionLabel: String,
        pageIndex: Int,
        strokes: [[String: [Double]]]
    ) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        lastLocalWriteTime = Date()
        // Update local hash so we don't re-render our own write
        lastStrokeHash[questionLabel] = strokes.count

        let row: [String: AnyJSON] = [
            "user_id": .string(userId),
            "document_id": .string(documentId),
            "question_label": .string(questionLabel),
            "page_index": .integer(pageIndex),
            "strokes": .array(strokes.map { stroke in
                .object([
                    "x": .array((stroke["x"] ?? []).map { .double($0) }),
                    "y": .array((stroke["y"] ?? []).map { .double($0) }),
                ])
            }),
        ]

        try? await supabase
            .from("canvas_strokes")
            .upsert(row, onConflict: "user_id,document_id,question_label")
            .execute()
    }

    // MARK: - Load Existing

    func loadStrokes(documentId: String) async -> [CanvasStrokeRow] {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return [] }

        let rows: [CanvasStrokeRow] = (try? await supabase
            .from("canvas_strokes")
            .select()
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .execute().value) ?? []

        // Initialize hash so we don't trigger updates for existing data
        for row in rows {
            lastStrokeHash[row.questionLabel] = row.strokes.count
        }

        return rows
    }

    // MARK: - Clear

    func clearStrokes(documentId: String, questionLabel: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }
        lastStrokeHash.removeValue(forKey: questionLabel)
        try? await supabase
            .from("canvas_strokes")
            .delete()
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .eq("question_label", value: questionLabel)
            .execute()
    }

    /// Clear strokes for all sub-questions of a question (e.g. Q1a, Q1b, Q1c).
    func clearStrokesForQuestion(documentId: String, questionLabels: [String]) async {
        for label in questionLabels {
            await clearStrokes(documentId: documentId, questionLabel: label)
        }
    }

    // MARK: - Stroke Extraction

    static func extractStrokePayloads(from drawing: PKDrawing) -> [[String: [Double]]] {
        drawing.strokes.map { stroke in
            var xs: [Double] = []
            var ys: [Double] = []
            for i in 0..<stroke.path.count {
                let pt = stroke.path[i].location
                xs.append(Double(pt.x))
                ys.append(Double(pt.y))
            }
            return ["x": xs, "y": ys]
        }
    }
}

// MARK: - Models

struct CanvasStrokeRow: Decodable {
    let questionLabel: String
    let pageIndex: Int
    let strokes: [StrokeData]
    let updatedAt: String?

    struct StrokeData: Decodable {
        let x: [Double]
        let y: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case questionLabel = "question_label"
        case pageIndex = "page_index"
        case strokes
        case updatedAt = "updated_at"
    }
}
