import SwiftUI

@Observable
@MainActor
final class DocumentsViewModel {
    var documents: [Document] = []
    var thumbnailURLs: [String: URL] = [:]
    var isLoading = true
    var loadError: String?
    var toastMessage: String?

    var deleteTarget: Document?
    var renameTarget: Document?
    var detailsTarget: Document?
    var moveToCourseTarget: Document?

    var showFilePicker = false
    var pendingUploadURL: URL?
    var maxDocuments: Int? = nil

    private var pollTask: Task<Void, Never>?
    private let repo: DocumentRepository

    init(repo: DocumentRepository = SupabaseDocumentRepository()) {
        self.repo = repo
    }

    // MARK: - Lifecycle

    func onAppear() async {
        let limits = TierLimits.current()
        if limits.maxDocuments != Int.max {
            maxDocuments = limits.maxDocuments
        }
        await fetchDocuments()
    }

    func onDisappear() {
        stopPolling()
    }

    // MARK: - Fetch

    func fetchDocuments() async {
        do {
            let data = try await repo.listDocuments()
            documents = data
            loadError = nil

            if !data.isEmpty {
                let urls = try await repo.getThumbnailURLs(data.map(\.id))
                thumbnailURLs.merge(urls) { _, new in new }
            }
        } catch {
            if documents.isEmpty {
                loadError = "Failed to load documents. Tap to retry."
            }
        }
        isLoading = false
        startPollingIfNeeded()
    }

    // MARK: - Polling (structured concurrency)

    private func startPollingIfNeeded() {
        let hasProcessing = documents.contains { $0.status == .processing }
        if hasProcessing && pollTask == nil {
            pollTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { break }
                    await fetchDocuments()
                }
            }
        } else if !hasProcessing {
            stopPolling()
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Upload

    func uploadDocument(result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            showToast("Failed to select file: \(error.localizedDescription)")
        case .success(let url):
            pendingUploadURL = url
        }
    }

    func performUploadWithOptions(courseId: String?, reconstruct: Bool) {
        guard let url = pendingUploadURL else { return }
        pendingUploadURL = nil
        Task { await performUpload(url: url, courseId: courseId, reconstruct: reconstruct) }
    }

    private func performUpload(url: URL, courseId: String?, reconstruct: Bool) async {
        guard url.startAccessingSecurityScopedResource() else {
            showToast("Cannot access file")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let doc = try await repo.uploadDocument(fileURL: url, courseId: courseId, reconstruct: reconstruct)
            documents.insert(doc, at: 0)
            // Fetch thumbnail URL for the newly uploaded doc
            if let urls = try? await repo.getThumbnailURLs([doc.id]),
               let thumbURL = urls[doc.id] {
                thumbnailURLs[doc.id] = thumbURL
            }
            if reconstruct {
                showToast("Document uploading — processing will begin shortly")
                startPollingIfNeeded()
            } else {
                showToast("Document uploaded")
            }
        } catch let uploadError as DocumentUploadError {
            showToast(uploadError.localizedDescription)
        } catch {
            showToast("Upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions (local updates where possible)

    func deleteDocument() async {
        guard let doc = deleteTarget else { return }
        do {
            try await repo.deleteDocument(doc.id)
            documents.removeAll { $0.id == doc.id }
            thumbnailURLs.removeValue(forKey: doc.id)
            showToast("Document deleted")
            deleteTarget = nil
        } catch {
            showToast("Something went wrong")
        }
    }

    func renameDocument(newFilename: String) async {
        guard let doc = renameTarget else { return }
        do {
            try await repo.renameDocument(doc.id, filename: newFilename)
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[idx] = Document(
                    id: doc.id, userId: doc.userId, filename: newFilename,
                    status: doc.status, pageCount: doc.pageCount,
                    problemCount: doc.problemCount, questionPages: doc.questionPages,
                    questionRegions: doc.questionRegions, errorMessage: doc.errorMessage,
                    statusMessage: doc.statusMessage, costCents: doc.costCents,
                    courseId: doc.courseId, createdAt: doc.createdAt
                )
            }
            showToast("Document renamed")
            renameTarget = nil
        } catch {
            showToast("Something went wrong")
        }
    }

    func downloadDocument(_ doc: Document) async {
        guard doc.status == .completed else { return }
        do {
            let url = try await repo.getDownloadURL(doc.id, preferOutput: true)
            await UIApplication.shared.open(url)
        } catch {
            showToast("Failed to download")
        }
    }

    func duplicateDocument(_ doc: Document) async {
        do {
            let newDoc = try await repo.duplicateDocument(doc.id)
            documents.insert(newDoc, at: 0)
            if let existingThumb = thumbnailURLs[doc.id] {
                thumbnailURLs[newDoc.id] = existingThumb
            }
            showToast("Document duplicated")
        } catch {
            showToast("Something went wrong")
        }
    }

    func moveDocumentToCourse(courseId: String?) async {
        guard let doc = moveToCourseTarget else { return }
        do {
            try await repo.moveDocumentToCourse(doc.id, courseId: courseId)
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[idx] = Document(
                    id: doc.id, userId: doc.userId, filename: doc.filename,
                    status: doc.status, pageCount: doc.pageCount,
                    problemCount: doc.problemCount, questionPages: doc.questionPages,
                    questionRegions: doc.questionRegions, errorMessage: doc.errorMessage,
                    statusMessage: doc.statusMessage, costCents: doc.costCents,
                    courseId: courseId, createdAt: doc.createdAt
                )
            }
            showToast(courseId != nil ? "Moved to course" : "Removed from course")
            moveToCourseTarget = nil
        } catch {
            showToast("Something went wrong")
        }
    }

    func retryDocument(_ doc: Document) async {
        do {
            try await repo.retryDocument(doc.id)
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[idx] = Document(
                    id: doc.id, userId: doc.userId, filename: doc.filename,
                    status: .processing, pageCount: doc.pageCount,
                    problemCount: doc.problemCount, questionPages: doc.questionPages,
                    questionRegions: doc.questionRegions,
                    errorMessage: nil, statusMessage: nil, costCents: nil,
                    courseId: doc.courseId, createdAt: doc.createdAt
                )
            }
            showToast("Retrying document processing...")
            startPollingIfNeeded()
        } catch {
            showToast("Failed to retry — please try again")
        }
    }

    func shareDocument(_ doc: Document) async {
        do {
            let url = try await repo.getShareURL(doc.id)
            UIPasteboard.general.string = url.absoluteString
            showToast("Share link copied to clipboard")
        } catch {
            showToast("Failed to generate share link")
        }
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toastMessage == message {
                withAnimation { toastMessage = nil }
            }
        }
    }
}
