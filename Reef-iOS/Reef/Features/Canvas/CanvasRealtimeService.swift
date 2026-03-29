import SwiftUI
import PencilKit
@preconcurrency import Supabase

@Observable
@MainActor
final class CanvasRealtimeService {
    var onStrokesReceived: ((CanvasStrokeRow) -> Void)?
    var onStrokesDeleted: (() -> Void)?
    var onChatMessageReceived: ((ChatMessageRow) -> Void)?

    private var strokesChannel: RealtimeChannelV2?
    private var chatChannel: RealtimeChannelV2?
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Subscribe

    func subscribe(documentId: String) async {
        unsubscribe()

        // Ensure Realtime is connected
        await supabase.realtimeV2.connect()

        // Subscribe to canvas_strokes changes for this document
        strokesChannel = supabase.realtimeV2.channel("strokes-\(documentId)")
        let strokeInserts = await strokesChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "canvas_strokes",
            filter: .eq("document_id", value: documentId)
        )
        let strokeDeletes = await strokesChannel!.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "canvas_strokes"
        )

        // Subscribe to chat_history changes for this document
        chatChannel = supabase.realtimeV2.channel("chat-\(documentId)")
        let chatChanges = await chatChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_history",
            filter: .eq("document_id", value: documentId)
        )

        try? await strokesChannel?.subscribeWithError()
        try? await chatChannel?.subscribeWithError()

        subscriptionTask = Task { [weak self] in
            // Listen for stroke inserts
            Task { [weak self] in
                for await change in strokeInserts {
                    guard let self else { return }
                    do {
                        let row = try change.decodeRecord(as: CanvasStrokeRow.self, decoder: JSONDecoder())
                        print("[Realtime] Stroke received: \(row.questionLabel) page=\(row.pageIndex)")
                        self.onStrokesReceived?(row)
                    } catch {
                        print("[Realtime] Stroke decode error: \(error)")
                    }
                }
            }
            // Listen for stroke deletes
            Task { [weak self] in
                for await _ in strokeDeletes {
                    guard let self else { return }
                    print("[Realtime] Strokes deleted")
                    self.onStrokesDeleted?()
                }
            }
            // Listen for chat changes
            for await change in chatChanges {
                guard let self else { return }
                do {
                    let row = try change.decodeRecord(as: ChatMessageRow.self, decoder: JSONDecoder())
                    print("[Realtime] Chat received: [\(row.role)] \(row.text.prefix(40))")
                    self.onChatMessageReceived?(row)
                } catch {
                    print("[Realtime] Chat decode error: \(error)")
                }
            }
        }

        print("[Realtime] Subscribed to strokes + chat for doc=\(documentId.prefix(12))")
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

    // MARK: - Write Strokes

    func writeStrokes(
        documentId: String,
        questionLabel: String,
        pageIndex: Int,
        strokes: [[String: [Double]]],
        latex: String = "",
        originX: Double = 30,
        originY: Double = 150
    ) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

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
            "latex": .string(latex),
            "origin_x": .double(originX),
            "origin_y": .double(originY),
        ]

        try? await supabase
            .from("canvas_strokes")
            .insert(row)
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
            .order("created_at", ascending: true)
            .execute().value) ?? []

        return rows
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

    // MARK: - Stroke Extraction Helper

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
    let id: String?
    let userId: String?
    let documentId: String?
    let questionLabel: String
    let pageIndex: Int
    let strokes: [StrokeData]
    let latex: String?
    let originX: Double?
    let originY: Double?
    let createdAt: String?
    let strokeCount: Int?

    struct StrokeData: Decodable {
        let x: [Double]
        let y: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case documentId = "document_id"
        case questionLabel = "question_label"
        case pageIndex = "page_index"
        case strokes, latex
        case originX = "origin_x"
        case originY = "origin_y"
        case createdAt = "created_at"
        case strokeCount = "stroke_count"
    }
}

struct ChatMessageRow: Decodable {
    let id: String?
    let role: String
    let text: String
    let questionLabel: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, role, text
        case questionLabel = "question_label"
        case createdAt = "created_at"
    }
}
