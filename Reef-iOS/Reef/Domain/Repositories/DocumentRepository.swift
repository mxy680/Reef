import Foundation

protocol DocumentRepository: Sendable {
    func listDocuments() async throws -> [Document]
    func uploadDocument(fileURL: URL, courseId: String?, reconstruct: Bool) async throws -> Document
    func deleteDocument(_ id: String) async throws
    func renameDocument(_ id: String, filename: String) async throws
    func duplicateDocument(_ id: String) async throws -> Document
    func moveDocumentToCourse(_ id: String, courseId: String?) async throws
    func retryDocument(_ id: String) async throws
    func getDownloadURL(_ id: String, preferOutput: Bool) async throws -> URL
    func getShareURL(_ id: String) async throws -> URL
    func getThumbnailURLs(_ ids: [String]) async throws -> [String: URL]
}
