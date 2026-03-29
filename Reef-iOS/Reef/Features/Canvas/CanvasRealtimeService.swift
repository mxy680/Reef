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

    private var strokesChannel: RealtimeChannelV2?
    private var chatChannel: RealtimeChannelV2?
    private var strokeListenTask: Task<Void, Never>?
    private var chatListenTask: Task<Void, Never>?

    // MARK: - Subscribe (matches Supabase SDK test pattern)

    func subscribe(documentId: String) async {
        unsubscribe()

        await supabase.realtimeV2.connect()

        // Create channels
        let sChannel = supabase.realtimeV2.channel("strokes-\(documentId)")
        let cChannel = supabase.realtimeV2.channel("chat-\(documentId)")
        strokesChannel = sChannel
        chatChannel = cChannel

        // Get the async streams
        let strokeChanges = await sChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "canvas_strokes"
        )
        let chatChanges = await cChannel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_history",
            filter: .eq("document_id", value: documentId)
        )

        // Start consuming BEFORE subscribing (matches SDK test pattern)
        strokeListenTask = Task { [weak self] in
            for await change in strokeChanges {
                guard let self else { return }

                // Skip own writes
                if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 {
                    continue
                }

                switch change {
                case .insert(let action):
                    print("[Realtime] Stroke INSERT")
                    self.decodeAndDeliverStroke(action)
                case .update(let action):
                    print("[Realtime] Stroke UPDATE")
                    self.decodeAndDeliverStroke(action)
                case .delete:
                    print("[Realtime] Strokes DELETE")
                    self.onStrokesDeleted?()
                }
            }
            print("[Realtime] Stroke listen loop ended")
        }

        chatListenTask = Task { [weak self] in
            for await change in chatChanges {
                guard let self else { return }
                do {
                    let row = try change.decodeRecord(as: ChatMessageRow.self, decoder: JSONDecoder())
                    print("[Realtime] Chat: [\(row.role)] \(row.text.prefix(40))")
                    self.onChatMessageReceived?(row)
                } catch {
                    print("[Realtime] Chat decode error: \(error)")
                }
            }
            print("[Realtime] Chat listen loop ended")
        }

        // NOW subscribe (after consumers are waiting)
        do {
            try await sChannel.subscribeWithError()
            print("[Realtime] Strokes channel subscribed")
        } catch {
            print("[Realtime] Strokes subscribe FAILED: \(error)")
        }

        do {
            try await cChannel.subscribeWithError()
            print("[Realtime] Chat channel subscribed")
        } catch {
            print("[Realtime] Chat subscribe FAILED: \(error)")
        }

        print("[Realtime] Subscribed for doc=\(documentId.prefix(12))")
    }

    private func decodeAndDeliverStroke(_ action: InsertAction) {
        do {
            let row = try action.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder())
            print("[Realtime] Stroke: \(row.questionLabel) page=\(row.pageIndex) strokes=\(row.strokes.count)")
            onStrokesUpdated?(row)
        } catch {
            print("[Realtime] Stroke decode error: \(error)")
        }
    }

    private func decodeAndDeliverStroke(_ action: UpdateAction) {
        do {
            let row = try action.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder())
            print("[Realtime] Stroke: \(row.questionLabel) page=\(row.pageIndex) strokes=\(row.strokes.count)")
            onStrokesUpdated?(row)
        } catch {
            print("[Realtime] Stroke decode error: \(error)")
        }
    }

    func unsubscribe() {
        strokeListenTask?.cancel()
        chatListenTask?.cancel()
        strokeListenTask = nil
        chatListenTask = nil
        let sc = strokesChannel
        let cc = chatChannel
        Task {
            await sc?.unsubscribe()
            await cc?.unsubscribe()
        }
        strokesChannel = nil
        chatChannel = nil
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
