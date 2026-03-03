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
