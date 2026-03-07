//
//  DrawingStorageService.swift
//  Reef
//
//  Persists per-page PKDrawing data as binary files
//

import Foundation
import PencilKit

@MainActor
enum DrawingStorageService {
    private static var baseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drawings")
    }

    // MARK: - Save All

    static func saveDrawings(_ drawings: [Int: PKDrawing], for documentId: String) {
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)

        for (pageIndex, drawing) in drawings {
            let fileURL = docDir.appendingPathComponent("page_\(pageIndex).pkdrawing")
            let data = drawing.dataRepresentation()
            try? data.write(to: fileURL)
        }
    }

    // MARK: - Save Single Page

    static func saveDrawing(_ drawing: PKDrawing, for documentId: String, pageIndex: Int) {
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)

        let fileURL = docDir.appendingPathComponent("page_\(pageIndex).pkdrawing")
        let data = drawing.dataRepresentation()
        try? data.write(to: fileURL)
    }

    // MARK: - Load

    static func loadDrawings(for documentId: String, pageCount: Int) -> [Int: PKDrawing] {
        var result: [Int: PKDrawing] = [:]
        let docDir = baseURL.appendingPathComponent(documentId)

        for i in 0..<pageCount {
            let fileURL = docDir.appendingPathComponent("page_\(i).pkdrawing")
            if let data = try? Data(contentsOf: fileURL),
               let drawing = try? PKDrawing(data: data) {
                result[i] = drawing
            }
        }
        return result
    }

    // MARK: - Delete

    nonisolated static func deleteDrawings(for documentId: String) {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drawings")
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.removeItem(at: docDir)
    }
}
