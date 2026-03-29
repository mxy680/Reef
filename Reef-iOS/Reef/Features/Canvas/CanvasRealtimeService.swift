import SwiftUI
import PencilKit
@preconcurrency import Supabase

/// Syncs canvas strokes and chat messages with Supabase via 1-second polling.
/// No Realtime, no WebSocket — just simple GET requests.
@Observable
@MainActor
final class CanvasSyncService {
    var onStrokesUpdated: ((CanvasStrokeRow) -> Void)?
    var onStrokesDeleted: (() -> Void)?
    var onChatMessageReceived: ((ChatMessageRow) -> Void)?
    var onTutorStateChanged: ((CanvasStrokeRow) -> Void)?

    /// Last seen tutor status per question — only fire callback on change
    private var lastTutorStatus: [String: String] = [:]

    /// Last known stroke hash per question — skip updates if unchanged
    private var lastStrokeHash: [String: Int] = [:]
    /// Last known chat count — only fetch new messages
    private var lastChatCount: Int = 0
    /// Timestamp of last local write — skip poll results within 2s
    private var lastLocalWriteTime: Date?

    private(set) var pollTimer: Timer?

    // MARK: - Start / Stop Polling

    func startPolling(documentId: String) {
        stopPolling()
        print("[Sync] Starting 1s poll for doc=\(documentId.prefix(12))")

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Skip if we just wrote locally
                if let lastWrite = self.lastLocalWriteTime, Date().timeIntervalSince(lastWrite) < 2.0 {
                    return
                }
                await self.pollForChanges(documentId: documentId)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        lastStrokeHash = [:]
        lastChatCount = 0
    }

    // MARK: - Poll

    private func pollForChanges(documentId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        // Poll strokes + tutor state
        let rows: [CanvasStrokeRow] = (try? await supabase
            .from("canvas_strokes")
            .select("question_label,page_index,strokes,updated_at,tutor_progress,tutor_status,tutor_step,tutor_steps_completed,tutor_speech_text")
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .execute().value) ?? []

        for row in rows {
            let hash = row.strokes.count  // Simple change detection
            if lastStrokeHash[row.questionLabel] != hash {
                lastStrokeHash[row.questionLabel] = hash
                onStrokesUpdated?(row)
            }

            // Detect tutor state changes
            let statusKey = "\(row.tutorStatus ?? "idle")_\(row.tutorProgress ?? 0)"
            if lastTutorStatus[row.questionLabel] != statusKey {
                lastTutorStatus[row.questionLabel] = statusKey
                if row.tutorStatus != nil && row.tutorStatus != "idle" {
                    onTutorStateChanged?(row)
                }
            }
        }

        // If we had rows before but now don't, something was deleted
        if rows.isEmpty && !lastStrokeHash.isEmpty {
            lastStrokeHash = [:]
            onStrokesDeleted?()
        }

        // Poll chat
        let chats: [ChatMessageRow] = (try? await supabase
            .from("chat_history")
            .select("role,text,question_label,speech_text")
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .order("created_at", ascending: true)
            .execute().value) ?? []

        if chats.count > lastChatCount {
            // New messages — deliver only the new ones
            for chat in chats.dropFirst(lastChatCount) {
                onChatMessageReceived?(chat)
            }
            lastChatCount = chats.count
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
    let tutorProgress: Double?
    let tutorStatus: String?
    let tutorStep: Int?
    let tutorStepsCompleted: Int?
    let tutorSpeechText: String?

    struct StrokeData: Decodable {
        let x: [Double]
        let y: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case questionLabel = "question_label"
        case pageIndex = "page_index"
        case strokes
        case updatedAt = "updated_at"
        case tutorProgress = "tutor_progress"
        case tutorStatus = "tutor_status"
        case tutorStep = "tutor_step"
        case tutorStepsCompleted = "tutor_steps_completed"
        case tutorSpeechText = "tutor_speech_text"
    }
}

struct ChatMessageRow: Decodable {
    let role: String
    let text: String
    let questionLabel: String
    let speechText: String?

    enum CodingKeys: String, CodingKey {
        case role, text
        case questionLabel = "question_label"
        case speechText = "speech_text"
    }
}
