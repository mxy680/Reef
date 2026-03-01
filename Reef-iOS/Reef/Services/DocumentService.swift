import Foundation
import PDFKit
import Supabase

enum DocumentServiceError: LocalizedError {
    case notAuthenticated
    case limitReached(String)
    case fileTooLarge(Int)
    case notPDF

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .limitReached(let msg):
            return msg
        case .fileTooLarge(let maxMB):
            return "File too large — max \(maxMB) MB on the free plan"
        case .notPDF:
            return "Please select a PDF file"
        }
    }
}

actor DocumentService {
    static let shared = DocumentService()

    private func getUserId() async throws -> String {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            throw DocumentServiceError.notAuthenticated
        }
        return userId
    }

    // MARK: - List

    func listDocuments() async throws -> [Document] {
        let response: [Document] = try await supabase
            .from("documents")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    // MARK: - Upload

    func uploadDocument(fileURL: URL) async throws -> Document {
        let userId = try await getUserId()

        // Validate PDF
        guard fileURL.pathExtension.lowercased() == "pdf" else {
            throw DocumentServiceError.notPDF
        }

        // Read file data
        let fileData = try Data(contentsOf: fileURL)

        // Check file size
        let limits = TierLimits.current()
        let maxBytes = limits.maxFileSizeMB * 1024 * 1024
        if fileData.count > maxBytes {
            throw DocumentServiceError.fileTooLarge(limits.maxFileSizeMB)
        }

        // Check document count
        let existingDocs: [Document] = try await supabase
            .from("documents")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        if existingDocs.count >= limits.maxDocuments {
            throw DocumentServiceError.limitReached("Document limit reached — upgrade to upload more")
        }

        // Insert DB row
        struct InsertPayload: Encodable {
            let user_id: String
            let filename: String
        }

        let newDoc: Document = try await supabase
            .from("documents")
            .insert(InsertPayload(user_id: userId, filename: fileURL.lastPathComponent))
            .select()
            .single()
            .execute()
            .value

        // Upload PDF to storage
        let storagePath = "\(userId)/\(newDoc.id)/original.pdf"
        do {
            try await supabase.storage
                .from("documents")
                .upload(storagePath, data: fileData, options: .init(contentType: "application/pdf"))
        } catch {
            // Clean up DB row on storage failure
            try? await supabase.from("documents").delete().eq("id", value: newDoc.id).execute()
            throw error
        }

        // Generate and upload thumbnail
        if let thumbnailData = generateThumbnail(from: fileURL) {
            let thumbPath = "\(userId)/\(newDoc.id)/thumbnail.png"
            try? await supabase.storage
                .from("documents")
                .upload(thumbPath, data: thumbnailData, options: .init(contentType: "image/png"))
        }

        // Fire-and-forget processing trigger
        Task.detached { [weak self] in
            try? await self?.triggerProcessing(documentId: newDoc.id)
        }

        return newDoc
    }

    // MARK: - Delete

    func deleteDocument(_ docId: String) async throws {
        let userId = try await getUserId()

        // Delete storage files
        let prefix = "\(userId)/\(docId)"
        let files = try await supabase.storage.from("documents").list(path: prefix)
        if !files.isEmpty {
            let paths = files.map { "\(prefix)/\($0.name)" }
            try await supabase.storage.from("documents").remove(paths: paths)
        }

        // Delete DB row
        try await supabase.from("documents").delete().eq("id", value: docId).execute()
    }

    // MARK: - Rename

    func renameDocument(_ docId: String, filename: String) async throws {
        struct UpdatePayload: Encodable {
            let filename: String
        }
        try await supabase
            .from("documents")
            .update(UpdatePayload(filename: filename))
            .eq("id", value: docId)
            .execute()
    }

    // MARK: - Duplicate

    func duplicateDocument(_ docId: String) async throws -> Document {
        let userId = try await getUserId()

        // Fetch original
        let original: Document = try await supabase
            .from("documents")
            .select()
            .eq("id", value: docId)
            .single()
            .execute()
            .value

        // Create new row
        struct InsertPayload: Encodable {
            let user_id: String
            let filename: String
            let status: String
            let page_count: Int?
            let problem_count: Int?
        }

        let newFilename = original.filename
            .replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive) + " (Copy).pdf"
        let newDoc: Document = try await supabase
            .from("documents")
            .insert(InsertPayload(
                user_id: userId,
                filename: newFilename,
                status: original.status.rawValue,
                page_count: original.pageCount,
                problem_count: original.problemCount
            ))
            .select()
            .single()
            .execute()
            .value

        // Copy storage files
        let prefix = "\(userId)/\(docId)"
        let files = try await supabase.storage.from("documents").list(path: prefix)
        for file in files {
            try? await supabase.storage
                .from("documents")
                .copy(from: "\(prefix)/\(file.name)", to: "\(userId)/\(newDoc.id)/\(file.name)")
        }

        return newDoc
    }

    // MARK: - Move to Course

    func moveDocumentToCourse(_ docId: String, courseId: String?) async throws {
        struct UpdatePayload: Encodable {
            let course_id: String?
        }
        try await supabase
            .from("documents")
            .update(UpdatePayload(course_id: courseId))
            .eq("id", value: docId)
            .execute()
    }

    // MARK: - Retry

    func retryDocument(_ docId: String) async throws {
        struct UpdatePayload: Encodable {
            let status: String
            let error_message: String?
        }
        try await supabase
            .from("documents")
            .update(UpdatePayload(status: "processing", error_message: nil))
            .eq("id", value: docId)
            .execute()

        Task.detached { [weak self] in
            try? await self?.triggerProcessing(documentId: docId)
        }
    }

    // MARK: - Download URL

    func getDownloadURL(_ docId: String) async throws -> URL {
        let userId = try await getUserId()
        return try await supabase.storage
            .from("documents")
            .createSignedURL(path: "\(userId)/\(docId)/output.pdf", expiresIn: 3600)
    }

    // MARK: - Share URL

    func getShareURL(_ docId: String) async throws -> URL {
        let userId = try await getUserId()
        do {
            return try await supabase.storage
                .from("documents")
                .createSignedURL(path: "\(userId)/\(docId)/output.pdf", expiresIn: 7 * 24 * 3600)
        } catch {
            // Fallback to original
            return try await supabase.storage
                .from("documents")
                .createSignedURL(path: "\(userId)/\(docId)/original.pdf", expiresIn: 7 * 24 * 3600)
        }
    }

    // MARK: - Thumbnail URLs

    func getThumbnailURLs(_ docIds: [String]) async throws -> [String: URL] {
        guard !docIds.isEmpty else { return [:] }
        let userId = try await getUserId()

        let paths = docIds.map { "\(userId)/\($0)/thumbnail.png" }
        let urls = try await supabase.storage
            .from("documents")
            .createSignedURLs(paths: paths, expiresIn: 3600)

        var result: [String: URL] = [:]
        for (i, url) in urls.enumerated() where i < docIds.count {
            result[docIds[i]] = url
        }
        return result
    }

    // MARK: - Private Helpers

    private func generateThumbnail(from fileURL: URL) -> Data? {
        guard let pdfDoc = PDFDocument(url: fileURL),
              let page = pdfDoc.page(at: 0) else { return nil }

        let thumbnail = page.thumbnail(of: CGSize(width: 400, height: 518), for: .mediaBox)
        return thumbnail.pngData()
    }

    private func triggerProcessing(documentId: String) async throws {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "REEF_WEB_URL") as? String,
              let url = URL(string: "\(baseURLString)/api/documents/process") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include auth token
        if let token = try? await supabase.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try? JSONEncoder().encode(["documentId": documentId])
        _ = try? await URLSession.shared.data(for: request)
    }
}
