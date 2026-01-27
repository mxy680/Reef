//
//  DrawingStorageService.swift
//  Reef
//
//  Service for persisting PencilKit drawings to disk
//

import Foundation
import PencilKit

// MARK: - Document Structure Model

/// Represents the structure of a multi-page document with modifications
struct DocumentStructure: Codable {
    /// Represents a single page in the document
    struct Page: Codable {
        enum PageType: String, Codable {
            case original  // Page from the original PDF/image
            case blank     // User-added blank page
        }

        let type: PageType
        let originalIndex: Int?  // For original pages, the index in the source file
    }

    var pages: [Page]
    let originalPageCount: Int  // Number of pages in the original source file

    /// Creates a default structure for a document with the given page count
    static func defaultStructure(pageCount: Int) -> DocumentStructure {
        let pages = (0..<pageCount).map { Page(type: .original, originalIndex: $0) }
        return DocumentStructure(pages: pages, originalPageCount: pageCount)
    }
}

class DrawingStorageService {
    static let shared = DrawingStorageService()

    private let fileManager = FileManager.default

    private var drawingsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drawings")
    }

    private var structuresDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DocumentStructures")
    }

    private init() {
        // Create directories if they don't exist
        if !fileManager.fileExists(atPath: drawingsDirectory.path) {
            try? fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: structuresDirectory.path) {
            try? fileManager.createDirectory(at: structuresDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Legacy Single-Page API (for backward compatibility)

    /// Saves a drawing to disk for the given document ID (legacy single-page)
    func saveDrawing(_ drawing: PKDrawing, for documentID: UUID) throws {
        try saveDrawing(drawing, for: documentID, pageIndex: 0)
    }

    /// Loads a drawing from disk for the given document ID (legacy single-page)
    /// Returns nil if no drawing exists or if loading fails
    func loadDrawing(for documentID: UUID) -> PKDrawing? {
        return loadDrawing(for: documentID, pageIndex: 0)
    }

    /// Deletes the drawing file for the given document ID (legacy - deletes all pages)
    func deleteDrawing(for documentID: UUID) {
        // Delete all page drawings
        let prefix = documentID.uuidString
        if let files = try? fileManager.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for file in files where file.hasPrefix(prefix) {
                try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(file))
            }
        }
        // Delete structure file
        let structureURL = getStructureURL(for: documentID)
        if fileManager.fileExists(atPath: structureURL.path) {
            try? fileManager.removeItem(at: structureURL)
        }
    }

    /// Checks if a drawing exists for the given document ID
    func drawingExists(for documentID: UUID) -> Bool {
        fileManager.fileExists(atPath: getDrawingURL(for: documentID, pageIndex: 0).path)
    }

    // MARK: - Multi-Page API

    /// Saves a drawing to disk for a specific page
    func saveDrawing(_ drawing: PKDrawing, for documentID: UUID, pageIndex: Int) throws {
        let url = getDrawingURL(for: documentID, pageIndex: pageIndex)
        let data = drawing.dataRepresentation()
        try data.write(to: url)
    }

    /// Loads a drawing from disk for a specific page
    func loadDrawing(for documentID: UUID, pageIndex: Int) -> PKDrawing? {
        let url = getDrawingURL(for: documentID, pageIndex: pageIndex)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        return drawing
    }

    /// Saves all drawings for a document
    func saveAllDrawings(_ drawings: [PKDrawing], for documentID: UUID) throws {
        for (index, drawing) in drawings.enumerated() {
            try saveDrawing(drawing, for: documentID, pageIndex: index)
        }
        // Clean up any drawings for pages that no longer exist
        cleanupExtraDrawings(for: documentID, keepingCount: drawings.count)
    }

    /// Loads all drawings for a document
    func loadAllDrawings(for documentID: UUID, pageCount: Int) -> [PKDrawing] {
        return (0..<pageCount).map { index in
            loadDrawing(for: documentID, pageIndex: index) ?? PKDrawing()
        }
    }

    // MARK: - Document Structure API

    /// Saves the document structure
    func saveDocumentStructure(_ structure: DocumentStructure, for documentID: UUID) throws {
        let url = getStructureURL(for: documentID)
        let data = try JSONEncoder().encode(structure)
        try data.write(to: url)
    }

    /// Loads the document structure
    func loadDocumentStructure(for documentID: UUID) -> DocumentStructure? {
        let url = getStructureURL(for: documentID)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let structure = try? JSONDecoder().decode(DocumentStructure.self, from: data) else {
            return nil
        }
        return structure
    }

    // MARK: - Private

    private func getDrawingURL(for documentID: UUID, pageIndex: Int) -> URL {
        drawingsDirectory.appendingPathComponent("\(documentID.uuidString)_page\(pageIndex).drawing")
    }

    private func getStructureURL(for documentID: UUID) -> URL {
        structuresDirectory.appendingPathComponent("\(documentID.uuidString).structure")
    }

    private func cleanupExtraDrawings(for documentID: UUID, keepingCount: Int) {
        let prefix = documentID.uuidString
        if let files = try? fileManager.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for file in files where file.hasPrefix(prefix) {
                // Extract page index from filename
                if let range = file.range(of: "_page"),
                   let endRange = file.range(of: ".drawing"),
                   let pageIndex = Int(file[range.upperBound..<endRange.lowerBound]),
                   pageIndex >= keepingCount {
                    try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(file))
                }
            }
        }
    }
}
