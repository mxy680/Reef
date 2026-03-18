import PencilKit
import UIKit

// MARK: - Drawing Manager (in-memory only, no persistence)

@MainActor
final class CanvasDrawingManager {
    /// Per-page PKDrawing data. Key = absolute page index.
    private(set) var drawings: [Int: PKDrawing] = [:]

    /// The currently active PKCanvasView (for undo/redo forwarding)
    weak var activeCanvasView: PKCanvasView?

    // MARK: - Get / Set

    func drawing(for pageIndex: Int) -> PKDrawing {
        drawings[pageIndex] ?? PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int) {
        drawings[pageIndex] = drawing
    }

    // MARK: - Undo / Redo

    var canUndo: Bool {
        activeCanvasView?.undoManager?.canUndo ?? false
    }

    var canRedo: Bool {
        activeCanvasView?.undoManager?.canRedo ?? false
    }

    func undo() {
        activeCanvasView?.undoManager?.undo()
    }

    func redo() {
        activeCanvasView?.undoManager?.redo()
    }
}
