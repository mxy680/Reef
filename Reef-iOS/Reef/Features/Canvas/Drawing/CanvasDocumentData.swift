import Foundation

// MARK: - Canvas Document Data (persisted state)

struct CanvasDocumentData: Codable {
    let documentId: String
    let originalPageCount: Int
    let addedPageIndices: [Int]
    let overlaySettings: CanvasOverlaySettings
    let currentPageIndex: Int
    /// Per-page PKDrawing binary data. String key because JSON doesn't support Int keys.
    let drawingDataByPage: [String: Data]
    /// Tutor progress per question/subquestion. Key format: "Q1a", "Q2b", etc.
    let tutorProgress: [String: TutorStepState]?
}

// MARK: - Tutor Step State (persisted per question/subquestion)

/// Saved state for a single question/subquestion's tutor progress.
struct TutorStepState: Codable {
    let currentStepIndex: Int
    let stepEvaluation: StepEvaluation?
    let lastTranscription: String
    let chatMessages: [SavedChatMessage]?
}

/// Persisted chat message.
struct SavedChatMessage: Codable {
    let role: String  // "student", "error", "reinforcement", or "answer"
    let latex: String
    let timestamp: Date
}

/// Saved evaluation result for a single step.
struct StepEvaluation: Codable {
    let progress: Double
    let status: String
    let mistakeExplanation: String?
}
