import Foundation
import PencilKit

actor DrawingStorageService {
    static let shared = DrawingStorageService()

    private var baseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("drawings")
    }

    // MARK: - Save

    func saveDrawings(_ drawings: [Int: PKDrawing], for documentId: String) {
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)

        for (pageIndex, drawing) in drawings {
            let fileURL = docDir.appendingPathComponent("page_\(pageIndex).drawing")
            try? drawing.dataRepresentation().write(to: fileURL)
        }
    }

    // MARK: - Load

    func loadDrawings(for documentId: String, pageCount: Int) -> [Int: PKDrawing] {
        var result: [Int: PKDrawing] = [:]
        let docDir = baseURL.appendingPathComponent(documentId)

        for i in 0..<pageCount {
            let fileURL = docDir.appendingPathComponent("page_\(i).drawing")
            if let data = try? Data(contentsOf: fileURL),
               let drawing = try? PKDrawing(data: data) {
                result[i] = drawing
            }
        }
        return result
    }

    // MARK: - Delete

    func deleteDrawings(for documentId: String) {
        let docDir = baseURL.appendingPathComponent(documentId)
        try? FileManager.default.removeItem(at: docDir)
    }
}
