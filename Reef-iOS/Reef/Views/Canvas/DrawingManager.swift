//
//  DrawingManager.swift
//  Reef
//
//  Centralized per-page PKDrawing state, undo/redo forwarding, and persistence
//

import PencilKit
import UIKit

@MainActor
final class DrawingManager {
    let documentId: String

    /// Per-page PKDrawing data. Key = absolute page index.
    private(set) var drawings: [Int: PKDrawing] = [:]

    /// Pages with unsaved changes
    private var dirtyPages: Set<Int> = []

    /// The currently active PKCanvasView (for undo/redo forwarding)
    weak var activeCanvasView: PKCanvasView?

    init(documentId: String) {
        self.documentId = documentId
    }

    // MARK: - Get / Set

    func drawing(for pageIndex: Int) -> PKDrawing {
        drawings[pageIndex] ?? PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int) {
        drawings[pageIndex] = drawing
        dirtyPages.insert(pageIndex)
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

    // MARK: - Persistence

    func loadAll(pageCount: Int) {
        drawings = DrawingStorageService.loadDrawings(
            for: documentId, pageCount: pageCount
        )
    }

    func saveAll() {
        guard !dirtyPages.isEmpty else { return }
        let toSave = dirtyPages.reduce(into: [Int: PKDrawing]()) { result, idx in
            if let d = drawings[idx] {
                result[idx] = d
            }
        }
        DrawingStorageService.saveDrawings(toSave, for: documentId)
        dirtyPages.removeAll()
    }

    func savePage(_ pageIndex: Int) {
        guard let drawing = drawings[pageIndex] else { return }
        DrawingStorageService.saveDrawing(drawing, for: documentId, pageIndex: pageIndex)
        dirtyPages.remove(pageIndex)
    }
}
