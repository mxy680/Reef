//
//  DocumentTextExtractor.swift
//  Reef
//
//  Orchestrates text extraction using both embedded (PDFKit) and OCR (Vision) methods
//

import Foundation
import PDFKit
import QuickLookThumbnailing
import UIKit

/// The method used for text extraction
enum ExtractionMethod: String, Codable {
    case embedded   // PDFKit embedded text only
    case ocr        // Vision OCR only
    case hybrid     // Both methods combined
}

/// Status of text extraction
enum ExtractionStatus: String, Codable {
    case pending
    case extracting
    case completed
    case failed
}

/// Result from document text extraction
struct DocumentExtractionResult {
    let text: String?
    let method: ExtractionMethod
    let confidence: Double?
}

/// Orchestrates text extraction from various document types
actor DocumentTextExtractor {
    static let shared = DocumentTextExtractor()

    private init() {}

    // MARK: - Public API

    /// Extract text from any supported file URL
    func extractText(from url: URL) async -> DocumentExtractionResult {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return await extractFromPDF(url: url)
        case "jpg", "jpeg", "png", "heic", "tiff", "gif":
            return await extractFromImage(url: url)
        default:
            return await extractFromOtherDocument(url: url)
        }
    }

    // MARK: - PDF Extraction

    private func extractFromPDF(url: URL) async -> DocumentExtractionResult {
        // Run embedded extraction and OCR in parallel
        async let embeddedTask = extractEmbeddedText(from: url)
        async let ocrTask = OCRTextExtractor.shared.extractTextFromPDF(at: url)

        let (embeddedText, ocrResult) = await (embeddedTask, ocrTask)

        // Determine which result to use based on content
        return mergeResults(embeddedText: embeddedText, ocrResult: ocrResult)
    }

    private func extractEmbeddedText(from url: URL) async -> String? {
        // Use existing PDFTextExtractor for embedded text
        return await PDFTextExtractor.shared.extractText(from: url)
    }

    private func mergeResults(embeddedText: String?, ocrResult: OCRResult) -> DocumentExtractionResult {
        let embeddedWordCount = embeddedText?.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count ?? 0
        let ocrWordCount = ocrResult.text?.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count ?? 0

        // If no embedded text, use OCR
        if embeddedWordCount == 0 {
            return DocumentExtractionResult(
                text: ocrResult.text,
                method: .ocr,
                confidence: ocrResult.confidence
            )
        }

        // If no OCR text, use embedded
        if ocrWordCount == 0 {
            return DocumentExtractionResult(
                text: embeddedText,
                method: .embedded,
                confidence: nil
            )
        }

        // If OCR finds significantly more content (>1.5x), combine them
        // This handles scanned documents with some embedded metadata
        if Double(ocrWordCount) > Double(embeddedWordCount) * 1.5 {
            // Combine: use embedded as base, then add unique OCR content
            let combinedText = combineTexts(embedded: embeddedText!, ocr: ocrResult.text!)
            return DocumentExtractionResult(
                text: combinedText,
                method: .hybrid,
                confidence: ocrResult.confidence
            )
        }

        // Embedded text is sufficient
        return DocumentExtractionResult(
            text: embeddedText,
            method: .embedded,
            confidence: nil
        )
    }

    private func combineTexts(embedded: String, ocr: String) -> String {
        // Simple combination: embedded text followed by OCR
        // Could be made smarter by deduplicating overlapping content
        let embeddedWords = Set(embedded.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map { String($0) })
        let ocrWords = ocr.split(whereSeparator: { $0.isWhitespace || $0.isNewline })

        // Find OCR words not in embedded (case-insensitive comparison)
        var uniqueOCRContent: [String] = []
        var consecutiveUnique: [String] = []

        for word in ocrWords {
            let lowercaseWord = word.lowercased()
            if !embeddedWords.contains(lowercaseWord) {
                consecutiveUnique.append(String(word))
            } else {
                // If we have accumulated unique words, add them as a chunk
                if consecutiveUnique.count >= 3 {
                    uniqueOCRContent.append(contentsOf: consecutiveUnique)
                }
                consecutiveUnique = []
            }
        }

        // Handle trailing unique content
        if consecutiveUnique.count >= 3 {
            uniqueOCRContent.append(contentsOf: consecutiveUnique)
        }

        if uniqueOCRContent.isEmpty {
            return embedded
        }

        return embedded + "\n\n--- Additional OCR Content ---\n\n" + uniqueOCRContent.joined(separator: " ")
    }

    // MARK: - Image Extraction

    private func extractFromImage(url: URL) async -> DocumentExtractionResult {
        let ocrResult = await OCRTextExtractor.shared.extractTextFromFileURL(url)

        return DocumentExtractionResult(
            text: ocrResult.text,
            method: .ocr,
            confidence: ocrResult.confidence
        )
    }

    // MARK: - Other Document Extraction

    private func extractFromOtherDocument(url: URL) async -> DocumentExtractionResult {
        // Try to render the document using Quick Look and then OCR it
        guard let image = await renderDocumentToImage(url: url) else {
            return DocumentExtractionResult(text: nil, method: .ocr, confidence: nil)
        }

        let ocrResult = await OCRTextExtractor.shared.extractTextFromImage(image)

        return DocumentExtractionResult(
            text: ocrResult.text,
            method: .ocr,
            confidence: ocrResult.confidence
        )
    }

    private func renderDocumentToImage(url: URL) async -> UIImage? {
        let size = CGSize(width: 1200, height: 1600)
        let scale: CGFloat = 2.0

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return thumbnail.uiImage
        } catch {
            print("Failed to generate document thumbnail for OCR: \(error)")
            return nil
        }
    }
}
