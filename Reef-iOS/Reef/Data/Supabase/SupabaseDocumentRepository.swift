import Foundation
import Supabase

struct SupabaseDocumentRepository: DocumentRepository {
    func listDocuments() async throws -> [Document] {
        let session = try await supabase.auth.session
        let dtos: [DocumentDTO] = try await supabase
            .from("documents")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    func uploadDocument(fileURL: URL, courseId: String?, reconstruct: Bool) async throws -> Document {
        // TODO: Implement full upload flow (validate, insert row, upload to storage, trigger processing)
        throw NSError(domain: "DocumentRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Upload not implemented yet"])
    }

    func deleteDocument(_ id: String) async throws {
        try await supabase.from("documents").delete().eq("id", value: id).execute()
    }

    func renameDocument(_ id: String, filename: String) async throws {
        try await supabase.from("documents").update(["filename": filename]).eq("id", value: id).execute()
    }

    func duplicateDocument(_ id: String) async throws -> Document {
        throw NSError(domain: "DocumentRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Duplicate not implemented yet"])
    }

    func moveDocumentToCourse(_ id: String, courseId: String?) async throws {
        if let courseId {
            try await supabase.from("documents").update(["course_id": courseId]).eq("id", value: id).execute()
        } else {
            try await supabase.from("documents").update(["course_id": AnyJSON.null]).eq("id", value: id).execute()
        }
    }

    func retryDocument(_ id: String) async throws {
        try await supabase.from("documents")
            .update(["status": "processing", "error_message": AnyJSON.null])
            .eq("id", value: id)
            .execute()
    }

    func getDownloadURL(_ id: String) async throws -> URL {
        let session = try await supabase.auth.session
        let path = "\(session.user.id.uuidString)/\(id)/output.pdf"
        let signedURL = try await supabase.storage.from("documents").createSignedURL(path: path, expiresIn: 3600)
        return signedURL
    }

    func getShareURL(_ id: String) async throws -> URL {
        try await getDownloadURL(id)
    }

    func getThumbnailURLs(_ ids: [String]) async throws -> [String: URL] {
        let session = try await supabase.auth.session
        var result: [String: URL] = [:]
        for id in ids {
            let path = "\(session.user.id.uuidString)/\(id)/thumbnail.png"
            if let url = try? await supabase.storage.from("documents").createSignedURL(path: path, expiresIn: 3600) {
                result[id] = url
            }
        }
        return result
    }
}
