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
    /// Unused — kept for backward-compat with existing saved data.
    let tutorProgress: [String: AnyCodable]?
    /// Last active question label so we resume where the user left off.
    let activeQuestionLabel: String?
}

/// Opaque codable wrapper for backward-compatible decoding of obsolete fields.
struct AnyCodable: Codable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}
