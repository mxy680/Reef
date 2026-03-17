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
        try await supabase.auth.session.user.id.uuidString
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

        // Validate PDF
        guard fileURL.pathExtension.lowercased() == "pdf" else {
            throw DocumentUploadError.notPDF
        }

        let fileData = try Data(contentsOf: fileURL)

        // Check file size
        let limits = TierLimits.current()
        let maxBytes = limits.maxFileSizeMB * 1024 * 1024
        if fileData.count > maxBytes {
            throw DocumentUploadError.fileTooLarge(limits.maxFileSizeMB)
        }

        // Check document count
        let existingDtos: [DocumentDTO] = try await supabase
            .from("documents")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        if existingDtos.count >= limits.maxDocuments {
            throw DocumentUploadError.limitReached
        }

        // Insert DB row
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

        // Upload PDF to storage
        let storagePath = "\(userId)/\(newDoc.id)/original.pdf"
        do {
            try await supabase.storage
                .from("documents")
                .upload(storagePath, data: fileData, options: .init(contentType: "application/pdf"))
        } catch {
            // Clean up DB row on storage failure
            _ = try? await supabase.from("documents").delete().eq("id", value: newDoc.id).execute()
            throw error
        }

        // Generate and upload thumbnail
        if let thumbnailData = generateThumbnail(from: fileURL) {
            let thumbPath = "\(userId)/\(newDoc.id)/thumbnail.png"
            _ = try? await supabase.storage
                .from("documents")
                .upload(thumbPath, data: thumbnailData, options: .init(contentType: "image/png"))
        }

        // TODO: Trigger reconstruction via ReefAPI when it's ported to clean architecture
        // For now, documents upload as "completed" without reconstruction

        return newDoc
    }

    // MARK: - Delete

    func deleteDocument(_ id: String) async throws {
        let userId = try await getUserId()

        // TODO: Cancel reconstruction via ReefAPI when ported

        // Delete storage files
        let prefix = "\(userId)/\(id)"
        let files = try await supabase.storage.from("documents").list(path: prefix)
        if !files.isEmpty {
            let paths = files.map { "\(prefix)/\($0.name)" }
            try await supabase.storage.from("documents").remove(paths: paths)
        }

        // Delete DB row
        try await supabase.from("documents").delete().eq("id", value: id).execute()
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

        // Fetch original
        let originalDto: DocumentDTO = try await supabase
            .from("documents")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        let original = originalDto.toDomain()

        // Insert copy
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

        // Copy storage files
        let srcPrefix = "\(userId)/\(id)"
        let dstPrefix = "\(userId)/\(copyDoc.id)"
        let files = try await supabase.storage.from("documents").list(path: srcPrefix)
        for file in files {
            _ = try? await supabase.storage.from("documents").copy(
                from: "\(srcPrefix)/\(file.name)",
                to: "\(dstPrefix)/\(file.name)"
            )
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

        // TODO: Trigger reconstruction via ReefAPI when ported
    }

    // MARK: - URLs

    func getDownloadURL(_ id: String) async throws -> URL {
        let userId = try await getUserId()
        let path = "\(userId)/\(id)/output.pdf"
        return try await supabase.storage.from("documents").createSignedURL(path: path, expiresIn: 3600)
    }

    func getShareURL(_ id: String) async throws -> URL {
        try await getDownloadURL(id)
    }

    func getThumbnailURLs(_ ids: [String]) async throws -> [String: URL] {
        let userId = try await getUserId()
        var result: [String: URL] = [:]
        for id in ids {
            let path = "\(userId)/\(id)/thumbnail.png"
            if let url = try? await supabase.storage.from("documents").createSignedURL(path: path, expiresIn: 3600) {
                result[id] = url
            }
        }
        return result
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
