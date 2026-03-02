//
//  CanvasViewModel.swift
//  Reef
//
//  Manages PDF loading, per-page drawing state, and tool configuration
//

import Foundation
import PDFKit

@Observable
@MainActor
final class CanvasViewModel {
    var pdfDocument: PDFDocument?
    var currentPageIndex: Int = 0
    var pageCount: Int = 0
    var isLoading = true
    var error: String?
    var fingerDrawing = false

    // Tool state
    var currentTool: DrawingTool = .pen
    var currentColor: StrokeColor = .black
    var currentLineWidth: CGFloat = 3.0

    // Per-page drawings keyed by page index
    var drawings: [Int: PageDrawing] = [:]

    // Undo / redo stacks per page (each entry is a snapshot of the strokes array)
    private var undoStack: [Int: [[Stroke]]] = [:]
    private var redoStack: [Int: [[Stroke]]] = [:]

    private var documentId: String = ""

    // MARK: - Computed

    var currentPage: PDFPage? {
        pdfDocument?.page(at: currentPageIndex)
    }

    var currentDrawing: PageDrawing {
        get { drawings[currentPageIndex] ?? PageDrawing() }
        set { drawings[currentPageIndex] = newValue }
    }

    var canGoBack: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex < pageCount - 1 }
    var canUndo: Bool { !(undoStack[currentPageIndex]?.isEmpty ?? true) }
    var canRedo: Bool { !(redoStack[currentPageIndex]?.isEmpty ?? true) }

    // MARK: - Load

    func loadDocument(_ document: Document) async {
        documentId = document.id
        isLoading = true
        error = nil

        do {
            let fileURL = try await DocumentService.shared.downloadPDF(document.id)

            guard let pdf = PDFDocument(url: fileURL) else {
                error = "Unable to open PDF"
                isLoading = false
                return
            }

            pdfDocument = pdf
            pageCount = pdf.pageCount
            drawings = DrawingStorageService.loadDrawings(
                for: documentId,
                pageCount: pageCount
            )
        } catch {
            self.error = "Failed to download document"
        }

        isLoading = false
    }

    // MARK: - Navigation

    func goToPage(_ index: Int) {
        guard index >= 0, index < pageCount, index != currentPageIndex else { return }
        saveCurrentDrawings()
        currentPageIndex = index
    }

    func nextPage() { goToPage(currentPageIndex + 1) }
    func previousPage() { goToPage(currentPageIndex - 1) }

    // MARK: - Drawing Actions

    func handleDrawingAction(_ action: DrawingAction) {
        let previousStrokes = currentDrawing.strokes
        undoStack[currentPageIndex, default: []].append(previousStrokes)
        redoStack[currentPageIndex] = []

        switch action {
        case .addStroke(let stroke):
            drawings[currentPageIndex, default: PageDrawing()].strokes.append(stroke)
        case .eraseStrokes(let remaining):
            drawings[currentPageIndex] = PageDrawing(strokes: remaining)
        }
    }

    func undo() {
        guard let previousStrokes = undoStack[currentPageIndex]?.popLast() else { return }
        let currentStrokes = currentDrawing.strokes
        redoStack[currentPageIndex, default: []].append(currentStrokes)
        drawings[currentPageIndex] = PageDrawing(strokes: previousStrokes)
    }

    func redo() {
        guard let nextStrokes = redoStack[currentPageIndex]?.popLast() else { return }
        let currentStrokes = currentDrawing.strokes
        undoStack[currentPageIndex, default: []].append(currentStrokes)
        drawings[currentPageIndex] = PageDrawing(strokes: nextStrokes)
    }

    // MARK: - Save

    func saveCurrentDrawings() {
        guard !documentId.isEmpty else { return }
        DrawingStorageService.saveDrawings(drawings, for: documentId)
    }
}
