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
}
