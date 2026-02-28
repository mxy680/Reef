//
//  OCRTextExtractor.swift
//  Reef
//
//  Actor-based service using Apple Vision framework for OCR text extraction
//

import Vision
import UIKit
import PDFKit

/// Result from OCR text extraction
struct OCRResult {
    let text: String?
    let confidence: Double
    let pageResults: [PageOCRResult]

    struct PageOCRResult {
        let pageIndex: Int
        let text: String
        let confidence: Double
    }
}

/// Actor-based OCR service using Apple Vision framework
actor OCRTextExtractor {
    static let shared = OCRTextExtractor()

    private init() {}

    // MARK: - Public API

    /// Extract text from a UIImage using Vision OCR
    func extractTextFromImage(_ image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else {
            return OCRResult(text: nil, confidence: 0, pageResults: [])
        }

        return await performOCR(on: cgImage, pageIndex: 0)
    }

    /// Extract text from a PDF document URL using OCR (renders pages to images)
    func extractTextFromPDF(at url: URL) async -> OCRResult {
        guard let document = PDFDocument(url: url) else {
            return OCRResult(text: nil, confidence: 0, pageResults: [])
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            return OCRResult(text: nil, confidence: 0, pageResults: [])
        }

        // Process pages in parallel using TaskGroup
        let pageResults = await withTaskGroup(of: OCRResult.PageOCRResult?.self) { group in
            for pageIndex in 0..<pageCount {
                group.addTask {
                    await self.extractTextFromPage(document: document, pageIndex: pageIndex)
                }
            }

            var results: [OCRResult.PageOCRResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }

            // Sort by page index to maintain order
            return results.sorted { $0.pageIndex < $1.pageIndex }
        }

        // Combine results
        let combinedText = pageResults.map { $0.text }.joined(separator: "\n\n")
        let averageConfidence = pageResults.isEmpty ? 0 : pageResults.map { $0.confidence }.reduce(0, +) / Double(pageResults.count)

        return OCRResult(
            text: combinedText.isEmpty ? nil : combinedText,
            confidence: averageConfidence,
            pageResults: pageResults
        )
    }

    /// Extract text from any file URL (images or PDFs)
    func extractTextFromFileURL(_ url: URL) async -> OCRResult {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "pdf" {
            return await extractTextFromPDF(at: url)
        } else if ["jpg", "jpeg", "png", "heic", "tiff", "gif"].contains(fileExtension) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                return OCRResult(text: nil, confidence: 0, pageResults: [])
            }
            return await extractTextFromImage(image)
        }

        // Unsupported file type
        return OCRResult(text: nil, confidence: 0, pageResults: [])
    }

    // MARK: - Private Methods

    private func extractTextFromPage(document: PDFDocument, pageIndex: Int) async -> OCRResult.PageOCRResult? {
        guard let page = document.page(at: pageIndex) else { return nil }

        // Render PDF page to image for OCR
        // Use 2x scale for better OCR accuracy
        let scale: CGFloat = 2.0
        let pageRect = page.bounds(for: .mediaBox)
        let renderSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        guard let cgImage = image.cgImage else { return nil }

        let result = await performOCR(on: cgImage, pageIndex: pageIndex)

        if let text = result.text, !text.isEmpty {
            return OCRResult.PageOCRResult(
                pageIndex: pageIndex,
                text: text,
                confidence: result.confidence
            )
        }

        return nil
    }

    private func performOCR(on cgImage: CGImage, pageIndex: Int) async -> OCRResult {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(text: nil, confidence: 0, pageResults: []))
                    return
                }

                var extractedTexts: [String] = []
                var totalConfidence: Double = 0

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        extractedTexts.append(topCandidate.string)
                        totalConfidence += Double(topCandidate.confidence)
                    }
                }

                let text = extractedTexts.joined(separator: "\n")
                let averageConfidence = observations.isEmpty ? 0 : totalConfidence / Double(observations.count)

                let pageResult = OCRResult.PageOCRResult(
                    pageIndex: pageIndex,
                    text: text,
                    confidence: averageConfidence
                )

                continuation.resume(returning: OCRResult(
                    text: text.isEmpty ? nil : text,
                    confidence: averageConfidence,
                    pageResults: text.isEmpty ? [] : [pageResult]
                ))
            }

            // Configure for accurate recognition with language correction
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: OCRResult(text: nil, confidence: 0, pageResults: []))
            }
        }
    }
}
