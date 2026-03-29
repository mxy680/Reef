import SwiftUI
import PencilKit
@preconcurrency import Supabase

@Observable
@MainActor
final class CanvasRealtimeService {
    var onStrokesUpdated: ((CanvasStrokeRow) -> Void)?
    var onStrokesDeleted: (() -> Void)?
    var onChatMessageReceived: ((ChatMessageRow) -> Void)?

    /// Timestamp of last local write — Realtime updates within 2s are our own echo
    private var lastLocalWriteTime: Date?

    private(set) var channel: RealtimeChannelV2?

    // MARK: - Subscribe (callback-based API from docs)

    func subscribe(documentId: String) async {
        unsubscribe()

        await supabase.realtimeV2.connect()

        // Single channel for all subscriptions
        let ch = supabase.realtimeV2.channel("canvas-\(documentId)")
        channel = ch

        // Strokes: listen for ALL changes (insert, update, delete)
        ch.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "canvas_strokes"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Skip own writes
                if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 {
                    return
                }

                switch action {
                case .insert(let insert):
                    print("[Realtime] Stroke INSERT")
                    if let row = try? insert.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder()) {
                        self.onStrokesUpdated?(row)
                    }
                case .update(let update):
                    print("[Realtime] Stroke UPDATE")
                    if let row = try? update.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder()) {
                        self.onStrokesUpdated?(row)
                    }
                case .delete:
                    print("[Realtime] Stroke DELETE")
                    self.onStrokesDeleted?()
                }
            }
        }

        // Chat: listen for inserts
        ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_history",
            filter: "document_id=eq.\(documentId)"
        ) { [weak self] insert in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let row = try? insert.decodeRecord(as: ChatMessageRow.self, decoder: JSONDecoder()) {
                    print("[Realtime] Chat: [\(row.role)] \(row.text.prefix(40))")
                    self.onChatMessageReceived?(row)
                }
            }
        }

        do {
            try await ch.subscribeWithError()
            print("[Realtime] Channel subscribed for doc=\(documentId.prefix(12))")
        } catch {
            print("[Realtime] Subscribe FAILED: \(error)")
        }
    }

    func unsubscribe() {
        let ch = channel
        channel = nil
        Task {
            if let ch { await supabase.realtimeV2.removeChannel(ch) }
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

        return (try? await supabase
            .from("canvas_strokes")
            .select()
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .execute().value) ?? []
    }

    // MARK: - Clear

    func clearStrokes(documentId: String, questionLabel: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }
        try? await supabase
            .from("canvas_strokes")
            .delete()
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .eq("question_label", value: questionLabel)
            .execute()
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

    struct StrokeData: Decodable {
        let x: [Double]
        let y: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case questionLabel = "question_label"
        case pageIndex = "page_index"
        case strokes
    }
}

struct ChatMessageRow: Decodable {
    let role: String
    let text: String
    let questionLabel: String

    enum CodingKeys: String, CodingKey {
        case role, text
        case questionLabel = "question_label"
    }
}
