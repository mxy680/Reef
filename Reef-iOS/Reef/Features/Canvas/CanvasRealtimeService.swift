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
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Subscribe

    func subscribe(documentId: String) async {
        unsubscribe()

        await supabase.realtimeV2.connect()

        // Subscribe to canvas_strokes UPDATE events (UPSERT triggers UPDATE after first insert)
        strokesChannel = supabase.realtimeV2.channel("strokes-\(documentId)")
        let strokeUpdates = await strokesChannel!.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "canvas_strokes",
            filter: .eq("document_id", value: documentId)
        )
        let strokeDeletes = await strokesChannel!.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "canvas_strokes"
        )
        // Also listen for INSERT (first write for a question creates the row)
        let strokeInserts = await strokesChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "canvas_strokes",
            filter: .eq("document_id", value: documentId)
        )

        // Subscribe to chat_history INSERT events
        chatChannel = supabase.realtimeV2.channel("chat-\(documentId)")
        let chatInserts = await chatChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_history",
            filter: .eq("document_id", value: documentId)
        )

        try? await strokesChannel?.subscribeWithError()
        try? await chatChannel?.subscribeWithError()

        subscriptionTask = Task { [weak self] in
            // Stroke UPDATES (from simulator upserts or own echo)
            Task { [weak self] in
                for await change in strokeUpdates {
                    guard let self else { return }
                    if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 { continue }
                    do {
                        let row = try change.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder())
                        print("[Realtime] Stroke update: \(row.questionLabel) page=\(row.pageIndex)")
                        self.onStrokesUpdated?(row)
                    } catch {
                        print("[Realtime] Stroke decode error: \(error)")
                    }
                }
            }
            // Stroke INSERTS (first write for a question)
            Task { [weak self] in
                for await change in strokeInserts {
                    guard let self else { return }
                    if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 { continue }
                    do {
                        let row = try change.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder())
                        print("[Realtime] Stroke insert: \(row.questionLabel) page=\(row.pageIndex)")
                        self.onStrokesUpdated?(row)
                    } catch {
                        print("[Realtime] Stroke decode error: \(error)")
                    }
                }
            }
            // Stroke DELETES
            Task { [weak self] in
                for await _ in strokeDeletes {
                    guard let self else { return }
                    print("[Realtime] Strokes deleted")
                    self.onStrokesDeleted?()
                }
            }
            // Chat INSERTS
            for await change in chatInserts {
                guard let self else { return }
                do {
                    let row = try change.decodeRecord(as: ChatMessageRow.self, decoder: JSONDecoder())
                    print("[Realtime] Chat: [\(row.role)] \(row.text.prefix(40))")
                    self.onChatMessageReceived?(row)
                } catch {
                    print("[Realtime] Chat decode error: \(error)")
                }
            }
        }

        print("[Realtime] Subscribed for doc=\(documentId.prefix(12))")
    }

    func unsubscribe() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
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
