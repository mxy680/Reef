import SwiftUI

@Observable
@MainActor
final class DocumentsViewModel {
    var documents: [Document] = []
    var thumbnailURLs: [String: URL] = [:]
    var isLoading = true
    var toastMessage: String?

    var deleteTarget: Document?
    var renameTarget: Document?
    var detailsTarget: Document?
    var moveToCourseTarget: Document?

    var showFilePicker = false
    var pendingUploadURL: URL?
    var maxDocuments: Int? = nil

    private var pollTimer: Timer?
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

            if !data.isEmpty {
                let urls = try await repo.getThumbnailURLs(data.map(\.id))
                thumbnailURLs.merge(urls) { _, new in new }
            }
        } catch {
            // Non-fatal — show empty state
        }
        isLoading = false
        startPollingIfNeeded()
    }

    // MARK: - Polling

    private func startPollingIfNeeded() {
        let hasProcessing = documents.contains { $0.status == .processing }
        if hasProcessing && pollTimer == nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchDocuments()
                }
            }
        } else if !hasProcessing {
            stopPolling()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
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

    // MARK: - Actions

    func deleteDocument() async {
        guard let doc = deleteTarget else { return }
        do {
            try await repo.deleteDocument(doc.id)
            showToast("Document deleted")
            deleteTarget = nil
            await fetchDocuments()
        } catch {
            showToast("Something went wrong")
        }
    }

    func renameDocument(newFilename: String) async {
        guard let doc = renameTarget else { return }
        do {
            try await repo.renameDocument(doc.id, filename: newFilename)
            showToast("Document renamed")
            renameTarget = nil
            await fetchDocuments()
        } catch {
            showToast("Something went wrong")
        }
    }

    func downloadDocument(_ doc: Document) async {
        guard doc.status == .completed else { return }
        do {
            let url = try await repo.getDownloadURL(doc.id)
            await UIApplication.shared.open(url)
        } catch {
            showToast("Failed to download")
        }
    }

    func duplicateDocument(_ doc: Document) async {
        do {
            let newDoc = try await repo.duplicateDocument(doc.id)
            showToast("Document duplicated")
            if let existingThumb = thumbnailURLs[doc.id] {
                thumbnailURLs[newDoc.id] = existingThumb
            }
            await fetchDocuments()
        } catch {
            showToast("Something went wrong")
        }
    }

    func moveDocumentToCourse(courseId: String?) async {
        guard let doc = moveToCourseTarget else { return }
        do {
            try await repo.moveDocumentToCourse(doc.id, courseId: courseId)
            showToast(courseId != nil ? "Moved to course" : "Removed from course")
            moveToCourseTarget = nil
            await fetchDocuments()
        } catch {
            showToast("Something went wrong")
        }
    }

    func retryDocument(_ doc: Document) async {
        do {
            try await repo.retryDocument(doc.id)
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                let updated = Document(
                    id: doc.id, userId: doc.userId, filename: doc.filename,
                    status: .processing, pageCount: doc.pageCount,
                    problemCount: doc.problemCount, questionPages: doc.questionPages,
                    questionRegions: doc.questionRegions,
                    errorMessage: nil, statusMessage: nil, costCents: nil,
                    courseId: doc.courseId, createdAt: doc.createdAt
                )
                documents[idx] = updated
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
