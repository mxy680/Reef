//
//  PDFExportService.swift
//  Reef
//
//  PDF compositing service for exporting documents with annotations
//

import UIKit
import PencilKit
import PDFKit

enum PDFExportService {

    // MARK: - Types

    struct PageExportData {
        let image: UIImage?
        let drawing: PKDrawing
        let pageSize: CGSize
    }

    enum ExportError: Error, LocalizedError {
        case noPages
        case renderingFailed

        var errorDescription: String? {
            switch self {
            case .noPages: return "No pages to export"
            case .renderingFailed: return "Failed to render PDF"
            }
        }
    }

    // MARK: - Export

    /// Generates a PDF from page export data, drawing document images and ink annotations
    /// directly into the PDF graphics context.
    static func generatePDF(pages: [PageExportData], fileName: String) async throws -> URL {
        guard !pages.isEmpty else { throw ExportError.noPages }

        let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReefExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        let fileURL = exportDir.appendingPathComponent(fileName)

        // Remove previous file if it exists
        try? FileManager.default.removeItem(at: fileURL)

        let firstPageSize = CGSize(width: pages[0].pageSize.width / 2, height: pages[0].pageSize.height / 2)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: firstPageSize))

        let data = pdfRenderer.pdfData { context in
            for page in pages {
                // PDF page = canvas size / 2 (canvas images are at 2x)
                let pdfPageSize = CGSize(width: page.pageSize.width / 2, height: page.pageSize.height / 2)
                let pageRect = CGRect(origin: .zero, size: pdfPageSize)

                context.beginPage(withBounds: pageRect, pageInfo: [:])

                // Layer 1: white background
                UIColor.white.setFill()
                UIRectFill(pageRect)

                // Layer 2: document image scaled from 2x canvas to 1x PDF
                if let image = page.image {
                    image.draw(in: pageRect)
                }

                // Layer 3: PencilKit drawing — render at full canvas size with light-mode
                // trait collection, then draw into PDF rect (UIImage.draw handles scaling)
                if !page.drawing.strokes.isEmpty {
                    let canvasRect = CGRect(origin: .zero, size: page.pageSize)
                    let lightTraits = UITraitCollection(userInterfaceStyle: .light)
                    var drawingImage: UIImage!
                    lightTraits.performAsCurrent {
                        drawingImage = page.drawing.image(from: canvasRect, scale: 1.0)
                    }
                    drawingImage.draw(in: pageRect)
                }
            }
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // MARK: - Assignment Export

    /// Generates a PDF that concatenates all assignment questions with their annotations.
    /// Iterates over every question, renders its PDF pages in light mode, loads saved drawings,
    /// and composites them into a single continuous PDF.
    static func generateAssignmentPDF(note: Note, fileName: String) async throws -> URL {
        let questions = note.extractedQuestions
        guard !questions.isEmpty else { throw ExportError.noPages }

        let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReefExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        let fileURL = exportDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)

        // Collect all pages across all questions
        var allPages: [PageExportData] = []

        for (questionIndex, question) in questions.enumerated() {
            let questionURL = FileStorageService.shared.getQuestionFileURL(
                questionSetID: note.id,
                fileName: question.pdfFileName
            )

            // Render question PDF pages in light mode (no dark filter)
            let pageImages = renderPDFPagesLightMode(url: questionURL)

            // Get the deterministic document ID for this question's drawings
            let combinedString = "\(note.id.uuidString)-question-\(questionIndex)"
            let questionDocID = UUID(uuidString: combinedString.md5UUID) ?? UUID()

            // Also check document structure for any user-added blank pages
            let structure = DrawingStorageService.shared.loadDocumentStructure(for: questionDocID)

            // Load saved drawings - use structure page count if available (may include added blank pages)
            let drawingPageCount = structure?.pages.count ?? pageImages.count
            let drawings = DrawingStorageService.shared.loadAllDrawings(for: questionDocID, pageCount: drawingPageCount)

            if let structure = structure {
                // Follow the saved structure (handles inserted blank pages)
                for (i, page) in structure.pages.enumerated() {
                    let drawing = i < drawings.count ? drawings[i] : PKDrawing()
                    let pageSize: CGSize
                    if i < pageImages.count {
                        pageSize = pageImages[i].size
                    } else if let first = pageImages.first {
                        pageSize = first.size
                    } else {
                        pageSize = CGSize(width: 1224, height: 1584)
                    }

                    switch page.type {
                    case .original:
                        let image: UIImage?
                        if let originalIndex = page.originalIndex, originalIndex < pageImages.count {
                            image = pageImages[originalIndex]
                        } else {
                            image = nil
                        }
                        allPages.append(PageExportData(image: image, drawing: drawing, pageSize: pageSize))
                    case .blank:
                        allPages.append(PageExportData(image: nil, drawing: drawing, pageSize: pageSize))
                    }
                }
            } else {
                // No structure - use original pages directly
                for (i, image) in pageImages.enumerated() {
                    let drawing = i < drawings.count ? drawings[i] : PKDrawing()
                    allPages.append(PageExportData(image: image, drawing: drawing, pageSize: image.size))
                }
            }
        }

        guard !allPages.isEmpty else { throw ExportError.noPages }
        return try await generatePDF(pages: allPages, fileName: fileName)
    }

    /// Renders all pages of a PDF at 2x scale in light mode (no dark filter applied).
    /// Uses explicit scale=1.0 format so image.size = pixel dimensions = canvas coordinate space.
    private static func renderPDFPagesLightMode(url: URL) -> [UIImage] {
        guard let document = PDFDocument(url: url) else { return [] }
        let pageCount = document.pageCount
        guard pageCount > 0 else { return [] }

        let renderScale: CGFloat = 2.0
        var images: [UIImage] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            let imageSize = CGSize(
                width: pageRect.width * renderScale,
                height: pageRect.height * renderScale
            )

            // Explicit 1x so image.size in points = pixel dimensions = canvas coordinates
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

            let pageImage = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))
                context.cgContext.translateBy(x: 0, y: pageRect.height * renderScale)
                context.cgContext.scaleBy(x: renderScale, y: -renderScale)
                page.draw(with: .mediaBox, to: context.cgContext)
            }

            images.append(pageImage)
        }

        return images
    }

    // MARK: - Cleanup

    static func cleanupExportFiles() {
        let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReefExport", isDirectory: true)
        try? FileManager.default.removeItem(at: exportDir)
    }
}
