//
//  TutorProgressStorageService.swift
//  Reef
//
//  Persists tutor step progress per document as JSON files.
//

import Foundation

@MainActor
enum TutorProgressStorageService {
    private static var baseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tutor_progress")
    }

    private static func fileURL(for documentId: String) -> URL {
        baseURL.appendingPathComponent("\(documentId).json")
    }

    // MARK: - Save

    static func save(
        stepProgress: [String: StepProgress],
        currentStepIndices: [String: Int],
        for documentId: String
    ) {
        let data = StoredProgress(
            stepProgress: stepProgress,
            currentStepIndices: currentStepIndices
        )
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try? JSONEncoder().encode(data).write(to: fileURL(for: documentId))
    }

    // MARK: - Load

    static func load(for documentId: String) -> StoredProgress? {
        guard let data = try? Data(contentsOf: fileURL(for: documentId)) else { return nil }
        return try? JSONDecoder().decode(StoredProgress.self, from: data)
    }

    // MARK: - Delete

    nonisolated static func delete(for documentId: String) {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tutor_progress")
        try? FileManager.default.removeItem(at: baseURL.appendingPathComponent("\(documentId).json"))
    }
}

struct StoredProgress: Codable {
    let stepProgress: [String: StepProgress]
    let currentStepIndices: [String: Int]
}
