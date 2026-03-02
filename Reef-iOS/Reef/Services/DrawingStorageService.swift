//
//  DrawingStorageService.swift
//  Reef
//
//  Persists per-page drawing data as JSON
//

import Foundation

@MainActor
enum DrawingStorageService {
    private static var baseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drawings")
    }

    // MARK: - Save

    static func saveDrawings(_ drawings: [Int: PageDrawing], for documentId: String) {
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        for (pageIndex, drawing) in drawings {
            let fileURL = docDir.appendingPathComponent("page_\(pageIndex).json")
            if let data = try? encoder.encode(drawing) {
                try? data.write(to: fileURL)
            }
        }
    }

    // MARK: - Load

    static func loadDrawings(for documentId: String, pageCount: Int) -> [Int: PageDrawing] {
        var result: [Int: PageDrawing] = [:]
        let docDir = baseURL.appendingPathComponent(documentId)
        let decoder = JSONDecoder()

        for i in 0..<pageCount {
            let fileURL = docDir.appendingPathComponent("page_\(i).json")
            if let data = try? Data(contentsOf: fileURL),
               let drawing = try? decoder.decode(PageDrawing.self, from: data) {
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
