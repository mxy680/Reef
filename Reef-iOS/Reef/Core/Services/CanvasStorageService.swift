import Foundation

// MARK: - Canvas Storage Service

enum CanvasStorageService {
    private static var baseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("canvas-data")
    }

    static func save(_ data: CanvasDocumentData) throws {
        let dir = baseDirectory.appendingPathComponent(data.documentId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("canvas-state.json")
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: fileURL, options: .atomic)
    }

    static func load(documentId: String) -> CanvasDocumentData? {
        let fileURL = baseDirectory
            .appendingPathComponent(documentId)
            .appendingPathComponent("canvas-state.json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CanvasDocumentData.self, from: data)
    }

    static func delete(documentId: String) throws {
        let dir = baseDirectory.appendingPathComponent(documentId)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }
}
