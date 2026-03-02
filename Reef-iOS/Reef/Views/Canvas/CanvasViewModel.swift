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
}
