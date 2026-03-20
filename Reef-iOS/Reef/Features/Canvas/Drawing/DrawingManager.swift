import SwiftUI
import PencilKit
import UIKit

// MARK: - Drawing Manager (in-memory only, no persistence)

@Observable
@MainActor
final class CanvasDrawingManager {
    /// Per-page PKDrawing data. Key = absolute page index.
    private(set) var drawings: [Int: PKDrawing] = [:]

    /// Incremented each time a drawing changes — used to trigger toolbar re-renders.
    var drawingVersion: Int = 0

    /// The currently active PKCanvasView (for undo/redo forwarding)
    weak var activeCanvasView: PKCanvasView?

    // MARK: - Get / Set

    func drawing(for pageIndex: Int) -> PKDrawing {
        drawings[pageIndex] ?? PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int) {
        drawings[pageIndex] = drawing
        drawingVersion += 1
    }

    // MARK: - Page Shift

    /// Shift all drawings at `index` and above up by one slot (for page insert).
    func shiftDrawingsForInsert(at index: Int) {
        // Process in descending order so we don't overwrite unprocessed entries
        let keys = drawings.keys.filter { $0 >= index }.sorted(by: >)
        for key in keys {
            drawings[key + 1] = drawings[key]
            drawings.removeValue(forKey: key)
        }
    }

    /// Remove drawing at `index` and shift all drawings above it down by one (for page delete).
    func shiftDrawingsForDelete(at index: Int) {
        drawings.removeValue(forKey: index)
        let keys = drawings.keys.filter { $0 > index }.sorted()
        for key in keys {
            drawings[key - 1] = drawings[key]
            drawings.removeValue(forKey: key)
        }
    }

    /// Returns true if a non-empty drawing exists at the given page index.
    func hasDrawing(for pageIndex: Int) -> Bool {
        guard let drawing = drawings[pageIndex] else { return false }
        return !drawing.strokes.isEmpty
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
