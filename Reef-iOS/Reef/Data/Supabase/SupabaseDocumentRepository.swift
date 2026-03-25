import Foundation
import PDFKit
import Supabase
import UIKit

enum DocumentUploadError: LocalizedError {
    case notAuthenticated
    case notPDF
    case fileTooLarge(Int)
    case limitReached

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not authenticated"
        case .notPDF: "Please select a PDF file"
        case .fileTooLarge(let mb): "File too large — max \(mb) MB on the free plan"
        case .limitReached: "Document limit reached — upgrade to upload more"
        }
    }
}

struct SupabaseDocumentRepository: DocumentRepository {

    private func getUserId() async throws -> String {
        try await supabase.auth.session.user.id.uuidString.lowercased()
    }

    // MARK: - List

    func listDocuments() async throws -> [Document] {
        let userId = try await getUserId()
        let dtos: [DocumentDTO] = try await supabase
            .from("documents")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    // MARK: - Upload

    func uploadDocument(fileURL: URL, courseId: String?, reconstruct: Bool) async throws -> Document {
        let userId = try await getUserId()

        guard fileURL.pathExtension.lowercased() == "pdf" else {
            throw DocumentUploadError.notPDF
        }

        let fileData = try Data(contentsOf: fileURL)

        let limits = TierLimits.current()
        let maxBytes = limits.maxFileSizeMB * 1024 * 1024
        if fileData.count > maxBytes {
            throw DocumentUploadError.fileTooLarge(limits.maxFileSizeMB)
        }

        // Count check — select only id column for efficiency
        struct IdOnly: Decodable { let id: String }
        let existing: [IdOnly] = try await supabase
            .from("documents")
            .select("id")
            .eq("user_id", value: userId)
            .execute()
            .value
        if existing.count >= limits.maxDocuments {
            throw DocumentUploadError.limitReached
        }

        struct InsertPayload: Encodable {
            let user_id: String
            let filename: String
            let course_id: String?
            let status: String?
        }

        let dto: DocumentDTO = try await supabase
            .from("documents")
            .insert(InsertPayload(
                user_id: userId,
                filename: fileURL.lastPathComponent,
                course_id: courseId,
                status: reconstruct ? nil : "completed"
            ))
            .select()
            .single()
            .execute()
            .value

        let newDoc = dto.toDomain()

        let storagePath = "\(userId)/\(newDoc.id)/original.pdf"
        do {
            try await supabase.storage
                .from("documents")
                .upload(storagePath, data: fileData, options: .init(contentType: "application/pdf"))
        } catch {
            _ = try? await supabase.from("documents").delete().eq("id", value: newDoc.id).execute()
            throw error
        }

        if let thumbnailData = generateThumbnail(from: fileURL) {
            let thumbPath = "\(userId)/\(newDoc.id)/thumbnail.png"
            _ = try? await supabase.storage
                .from("documents")
                .upload(thumbPath, data: thumbnailData, options: .init(contentType: "image/png"))
        }

        // Trigger reconstruction on the server if requested
        if reconstruct {
            do {
                try await triggerReconstruction(documentId: newDoc.id)
            } catch {
                print("[DocumentRepo] Reconstruction trigger failed for \(newDoc.id): \(error)")
            }
        }

        return newDoc
    }

    private func triggerReconstruction(documentId: String) async throws {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/v2/reconstruct-document") else { return }

        let session = try await supabase.auth.session
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["document_id": documentId])
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Delete

    func deleteDocument(_ id: String) async throws {
        let userId = try await getUserId()

        // Delete DB row first — user-visible record gone immediately
        try await supabase.from("documents").delete().eq("id", value: id).execute()

        // Best-effort storage cleanup after DB delete
        let prefix = "\(userId)/\(id)"
        if let files = try? await supabase.storage.from("documents").list(path: prefix),
           !files.isEmpty {
            let paths = files.map { "\(prefix)/\($0.name)" }
            _ = try? await supabase.storage.from("documents").remove(paths: paths)
        }
    }

    // MARK: - Rename

    func renameDocument(_ id: String, filename: String) async throws {
        try await supabase
            .from("documents")
            .update(["filename": filename])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Duplicate

    func duplicateDocument(_ id: String) async throws -> Document {
        let userId = try await getUserId()

        let originalDto: DocumentDTO = try await supabase
            .from("documents")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        let original = originalDto.toDomain()

        struct InsertPayload: Encodable {
            let user_id: String
            let filename: String
            let status: String
            let page_count: Int?
            let problem_count: Int?
            let course_id: String?
        }

        let copyDto: DocumentDTO = try await supabase
            .from("documents")
            .insert(InsertPayload(
                user_id: userId,
                filename: "Copy of \(original.filename)",
                status: original.status.rawValue,
                page_count: original.pageCount,
                problem_count: original.problemCount,
                course_id: original.courseId
            ))
            .select()
            .single()
            .execute()
            .value

        let copyDoc = copyDto.toDomain()

        // Copy storage files — log failures but don't throw
        let srcPrefix = "\(userId)/\(id)"
        let dstPrefix = "\(userId)/\(copyDoc.id)"
        if let files = try? await supabase.storage.from("documents").list(path: srcPrefix) {
            for file in files {
                do {
                    try await supabase.storage.from("documents").copy(
                        from: "\(srcPrefix)/\(file.name)",
                        to: "\(dstPrefix)/\(file.name)"
                    )
                } catch {
                    print("[DocumentRepo] Failed to copy \(file.name) for duplicate: \(error)")
                }
            }
        }

        return copyDoc
    }

    // MARK: - Move to Course

    func moveDocumentToCourse(_ id: String, courseId: String?) async throws {
        if let courseId {
            try await supabase.from("documents").update(["course_id": courseId]).eq("id", value: id).execute()
        } else {
            try await supabase.from("documents").update(["course_id": AnyJSON.null]).eq("id", value: id).execute()
        }
    }

    // MARK: - Retry

    func retryDocument(_ id: String) async throws {
        try await supabase.from("documents")
            .update(["status": "processing", "error_message": AnyJSON.null])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Single Document

    func getDocument(_ id: String) async throws -> Document {
        let userId = try await getUserId()
        let dto: DocumentDTO = try await supabase.from("documents")
            .select()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    // MARK: - URLs

    func getDownloadURL(_ id: String, preferOutput: Bool = true) async throws -> URL {
        let userId = try await getUserId()
        if preferOutput {
            // Try output.pdf first (reconstructed), fall back to original.pdf
            do {
                return try await supabase.storage.from("documents")
                    .createSignedURL(path: "\(userId)/\(id)/output.pdf", expiresIn: 3600)
            } catch {
                return try await supabase.storage.from("documents")
                    .createSignedURL(path: "\(userId)/\(id)/original.pdf", expiresIn: 3600)
            }
        } else {
            // Document not reconstructed — go directly to original
            return try await supabase.storage.from("documents")
                .createSignedURL(path: "\(userId)/\(id)/original.pdf", expiresIn: 3600)
        }
    }

    func getShareURL(_ id: String) async throws -> URL {
        // Currently identical to download URL — will diverge when sharing features are built
        try await getDownloadURL(id)
    }

    // HIGH-2 fix: concurrent thumbnail URL fetching
    func getThumbnailURLs(_ ids: [String]) async throws -> [String: URL] {
        let userId = try await getUserId()
        return await withTaskGroup(of: (String, URL?).self) { group in
            for id in ids {
                group.addTask {
                    let path = "\(userId)/\(id)/thumbnail.png"
                    let url = try? await supabase.storage.from("documents")
                        .createSignedURL(path: path, expiresIn: 3600)
                    return (id, url)
                }
            }
            var result: [String: URL] = [:]
            for await (id, url) in group {
                if let url { result[id] = url }
            }
            return result
        }
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(from url: URL) -> Data? {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: 0) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 400 / bounds.width
        let size = CGSize(width: 400, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        return image.pngData()
    }
}
