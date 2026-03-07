//
//  CanvasViewModel.swift
//  Reef
//
//  Downloads and provides the PDFDocument for the canvas
//

import Foundation
import PDFKit

@Observable
@MainActor
final class CanvasViewModel {
    var pdfDocument: PDFDocument?
    var isLoading = true
    var error: String?

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
        } catch {
            self.error = "Failed to download document"
        }

        isLoading = false
    }

    // MARK: - Page Management

    var pageCount: Int {
        pdfDocument?.pageCount ?? 0
    }

    func addBlankPage(at index: Int) {
        guard let pdf = pdfDocument else { return }
        let page = createBlankPage(matchingSizeOf: pdf)
        pdf.insert(page, at: min(index, pdf.pageCount))
    }

    func deletePageAt(_ index: Int) {
        guard let pdf = pdfDocument, pdf.pageCount > 1, index < pdf.pageCount else { return }
        pdf.removePage(at: index)
    }

    func deleteAllPages() {
        guard let pdf = pdfDocument, pdf.pageCount > 0 else { return }
        let size = pdf.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
        while pdf.pageCount > 0 {
            pdf.removePage(at: 0)
        }
        let blank = createBlankPage(size: size)
        pdf.insert(blank, at: 0)
    }

    private func createBlankPage(matchingSizeOf pdf: PDFDocument) -> PDFPage {
        let size = pdf.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
        return createBlankPage(size: size)
    }

    private func createBlankPage(size: CGSize) -> PDFPage {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
        }
        return PDFDocument(data: data)!.page(at: 0)!
    }

    #if DEBUG
    /// Creates a blank test PDF for dev mode canvas testing
    func loadTestDocument() {
        isLoading = true
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            // Blank white page — just for toolbar testing
        }
        pdfDocument = PDFDocument(data: data)
        isLoading = false
    }
    #endif
}
