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
    /// Called once on startup with all rows so the ViewModel can restore tutor step indices
    var onInitialTutorStateLoaded: (([CanvasStrokeRow]) -> Void)?
    #if DEBUG
    var onChunkBboxesUpdated: (([[Double]]) -> Void)?
    #endif

    /// Last seen tutor status per question — only fire callback on change
    private var lastTutorStatus: [String: String] = [:]
    /// Suppress polled TTS after local eval fires
    var lastLocalEvalTime: Date?
    /// True while loading existing chat history on startup — suppresses TTS in the callback
    var isLoadingHistory = false
    /// True while a chat delete is in flight — suppresses poller from re-delivering stale rows
    private var isClearingChat = false
    /// Suppress polled chat messages briefly after local chat send
    var lastLocalChatTime: Date?

    /// Last known stroke hash per question — skip updates if unchanged
    private var lastStrokeHash: [String: Int] = [:]
    /// Last known chat count per question label — only deliver new messages
    private var lastChatCount: [String: Int] = [:]
    /// Timestamp of last local write — skip poll results within 2s
    private var lastLocalWriteTime: Date?

    private(set) var pollTimer: Timer?

    // MARK: - Start / Stop Polling

    func startPolling(documentId: String) {
        stopPolling()
        print("[Sync] Starting 1s poll for doc=\(documentId.prefix(12))")

        // Load existing chat messages so sidebar shows prior history,
        // then start the poll timer only AFTER preload completes (avoids races).
        Task { @MainActor [weak self] in
            guard let self, let userId = try? await supabase.auth.session.user.id.uuidString else { return }
            let chats: [ChatMessageRow] = (try? await supabase
                .from("chat_history")
                .select("role,text,question_label,speech_text")
                .eq("user_id", value: userId)
                .eq("document_id", value: documentId)
                .order("created_at", ascending: true)
                .execute().value) ?? []
            // Set per-label counts so the poller only delivers NEW messages
            for chat in chats {
                self.lastChatCount[chat.questionLabel, default: 0] += 1
            }
            // Deliver existing messages to the UI (without TTS — they're old)
            self.isLoadingHistory = true
            for chat in chats {
                self.onChatMessageReceived?(chat)
            }
            self.isLoadingHistory = false
            print("[Sync] Pre-loaded \(chats.count) existing chat messages")

            // Load tutor state (step index, progress, status) from canvas_strokes
            let selectCols = "question_label,page_index,strokes,updated_at,tutor_progress,tutor_status,tutor_step,tutor_steps_completed,tutor_speech_text"
            let rows: [CanvasStrokeRow] = (try? await supabase
                .from("canvas_strokes")
                .select(selectCols)
                .eq("user_id", value: userId)
                .eq("document_id", value: documentId)
                .execute().value) ?? []
            // Seed poller hashes so the first tick doesn't re-deliver these
            for row in rows {
                self.lastStrokeHash[row.questionLabel] = row.strokes.count
                let statusKey = "\(row.tutorStatus ?? "idle")_\(row.tutorProgress ?? 0)"
                self.lastTutorStatus[row.questionLabel] = statusKey
            }
            self.onInitialTutorStateLoaded?(rows)
            print("[Sync] Pre-loaded tutor state for \(rows.count) questions")

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
        lastChatCount = [:]
    }

    // MARK: - Poll

    private func pollForChanges(documentId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        // Poll strokes + tutor state
        #if DEBUG
        let selectColumns = "question_label,page_index,strokes,updated_at,tutor_progress,tutor_status,tutor_step,tutor_steps_completed,tutor_speech_text,transcription_chunks"
        #else
        let selectColumns = "question_label,page_index,strokes,updated_at,tutor_progress,tutor_status,tutor_step,tutor_steps_completed,tutor_speech_text"
        #endif
        let rows: [CanvasStrokeRow] = (try? await supabase
            .from("canvas_strokes")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .execute().value) ?? []

        for row in rows {
            let hash = row.strokes.count  // Simple change detection
            if lastStrokeHash[row.questionLabel] != hash {
                lastStrokeHash[row.questionLabel] = hash
                // Only replace canvas if we haven't written locally recently —
                // external sources (simulation, another device) can push strokes.
                let isExternalWrite = lastLocalWriteTime == nil || Date().timeIntervalSince(lastLocalWriteTime!) > 5.0
                if isExternalWrite {
                    onStrokesUpdated?(row)
                }
            }

            // Detect tutor state changes
            let statusKey = "\(row.tutorStatus ?? "idle")_\(row.tutorProgress ?? 0)"
            if lastTutorStatus[row.questionLabel] != statusKey {
                lastTutorStatus[row.questionLabel] = statusKey
                if row.tutorStatus != nil && row.tutorStatus != "idle" {
                    onTutorStateChanged?(row)
                }
            }

            #if DEBUG
            // Deliver chunk bboxes for debug overlay
            if let chunks = row.transcriptionChunks {
                let bboxes = chunks.compactMap { $0.bbox }
                onChunkBboxesUpdated?(bboxes)
            }
            #endif
        }

        // If we had rows before but now don't, something was deleted
        if rows.isEmpty && !lastStrokeHash.isEmpty {
            lastStrokeHash = [:]
            onStrokesDeleted?()
        }

        // Poll chat — skip if clearing or just sent a local chat
        if isClearingChat { return }
        if let lastChat = lastLocalChatTime, Date().timeIntervalSince(lastChat) < 5.0 {
            return
        }

        let chats: [ChatMessageRow] = (try? await supabase
            .from("chat_history")
            .select("role,text,question_label,speech_text")
            .eq("user_id", value: userId)
            .eq("document_id", value: documentId)
            .order("created_at", ascending: true)
            .execute().value) ?? []

        // Group by question label and only deliver new messages per label
        let grouped = Dictionary(grouping: chats, by: \.questionLabel)
        for (label, labelChats) in grouped {
            let known = lastChatCount[label, default: 0]
            if labelChats.count > known {
                for chat in labelChats.dropFirst(known) {
                    onChatMessageReceived?(chat)
                }
                lastChatCount[label] = labelChats.count
            }
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
        lastTutorStatus.removeValue(forKey: questionLabel)
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

    func clearChat(documentId: String, questionLabel: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            print("[Sync] clearChat FAILED — no userId")
            return
        }
        print("[Sync] clearChat: deleting chat for label=\(questionLabel) doc=\(documentId.prefix(12)) user=\(userId.prefix(8))")
        do {
            try await supabase
                .from("chat_history")
                .delete()
                .eq("user_id", value: userId)
                .eq("document_id", value: documentId)
                .eq("question_label", value: questionLabel)
                .execute()
            print("[Sync] clearChat: SUCCESS for label=\(questionLabel)")
        } catch {
            print("[Sync] clearChat: ERROR for label=\(questionLabel): \(error)")
        }
        lastChatCount.removeValue(forKey: questionLabel)
    }

    /// Clear chat for all sub-questions of a question.
    /// `isClearingChat` suppresses the poller from re-delivering stale rows during the deletes.
    func clearChatForQuestion(documentId: String, questionLabels: [String]) async {
        guard !questionLabels.isEmpty else { return }
        isClearingChat = true
        defer { isClearingChat = false }
        for label in questionLabels {
            await clearChat(documentId: documentId, questionLabel: label)
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

struct ChunkInfo: Decodable {
    let bbox: [Double]?
    let fingerprint: String?
    let latex: String?
}

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
    #if DEBUG
    let transcriptionChunks: [ChunkInfo]?
    #endif

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
        #if DEBUG
        case transcriptionChunks = "transcription_chunks"
        #endif
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
