import Foundation
import PDFKit
import PencilKit

@Observable
@MainActor
final class CanvasViewModel {
    var pdfDocument: PDFDocument?
    var currentPageIndex: Int = 0
    var pageCount: Int = 0
    var isLoading = true
    var error: String?
    var fingerDrawing = false

    // Per-page drawings keyed by page index
    var drawings: [Int: PKDrawing] = [:]

    private var documentId: String = ""

    // MARK: - Current State

    var currentPage: PDFPage? {
        pdfDocument?.page(at: currentPageIndex)
    }

    var currentDrawing: PKDrawing {
        get { drawings[currentPageIndex] ?? PKDrawing() }
        set { drawings[currentPageIndex] = newValue }
    }

    var canGoBack: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex < pageCount - 1 }

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

            // Load saved drawings
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

    func nextPage() {
        goToPage(currentPageIndex + 1)
    }

    func previousPage() {
        goToPage(currentPageIndex - 1)
    }

    // MARK: - Save

    func saveCurrentDrawings() {
        guard !documentId.isEmpty else { return }
        DrawingStorageService.saveDrawings(drawings, for: documentId)
    }
}
