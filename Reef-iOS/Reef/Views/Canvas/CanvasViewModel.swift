//
//  CanvasViewModel.swift
//  Reef
//
//  Manages PDF loading and page navigation
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

    var currentPage: PDFPage? {
        pdfDocument?.page(at: currentPageIndex)
    }

    var canGoBack: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex < pageCount - 1 }

    func loadDocument(_ document: Document) async {
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
        } catch {
            self.error = "Failed to download document"
        }

        isLoading = false
    }

    func nextPage() {
        guard canGoForward else { return }
        currentPageIndex += 1
    }

    func previousPage() {
        guard canGoBack else { return }
        currentPageIndex -= 1
    }
}
