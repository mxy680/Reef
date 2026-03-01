import SwiftUI
import UniformTypeIdentifiers

// MARK: - ViewModel

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
    var maxDocuments: Int? = nil

    private var pollTimer: Timer?

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
            let data = try await DocumentService.shared.listDocuments()
            documents = data

            if !data.isEmpty {
                let urls = try await DocumentService.shared.getThumbnailURLs(data.map(\.id))
                thumbnailURLs.merge(urls) { _, new in new }
            }
        } catch {
            print("Failed to fetch documents: \(error)")
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

    func uploadDocument(result: Result<URL, Error>) async {
        switch result {
        case .failure(let error):
            showToast("Failed to select file: \(error.localizedDescription)")
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                showToast("Cannot access file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let doc = try await DocumentService.shared.uploadDocument(fileURL: url)
                documents.insert(doc, at: 0)
                showToast("Document uploading — processing will begin shortly")
                startPollingIfNeeded()
            } catch let error as DocumentServiceError {
                showToast(error.localizedDescription ?? "Upload failed")
            } catch {
                showToast("Upload failed — please try again")
            }
        }
    }

    // MARK: - Actions

    func deleteDocument() async {
        guard let doc = deleteTarget else { return }
        do {
            try await DocumentService.shared.deleteDocument(doc.id)
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
            try await DocumentService.shared.renameDocument(doc.id, filename: newFilename)
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
            let url = try await DocumentService.shared.getDownloadURL(doc.id)
            await UIApplication.shared.open(url)
        } catch {
            showToast("Failed to download")
        }
    }

    func duplicateDocument(_ doc: Document) async {
        do {
            let newDoc = try await DocumentService.shared.duplicateDocument(doc.id)
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
            try await DocumentService.shared.moveDocumentToCourse(doc.id, courseId: courseId)
            showToast(courseId != nil ? "Moved to course" : "Removed from course")
            moveToCourseTarget = nil
            await fetchDocuments()
        } catch {
            showToast("Something went wrong")
        }
    }

    func retryDocument(_ doc: Document) async {
        do {
            try await DocumentService.shared.retryDocument(doc.id)
            if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                // Optimistically update local state
                let updated = Document(
                    id: doc.id, userId: doc.userId, filename: doc.filename,
                    status: .processing, pageCount: doc.pageCount,
                    problemCount: doc.problemCount, errorMessage: nil,
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
            let url = try await DocumentService.shared.getShareURL(doc.id)
            UIPasteboard.general.string = url.absoluteString
            showToast("Share link copied to clipboard")
        } catch {
            showToast("Failed to generate share link")
        }
    }

    func openDocument(_ doc: Document) async {
        guard doc.status == .completed else { return }
        do {
            let url = try await DocumentService.shared.getDownloadURL(doc.id)
            await UIApplication.shared.open(url)
        } catch {
            showToast("Failed to open document")
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

// MARK: - Main View

struct DocumentsContentView: View {
    @State private var viewModel = DocumentsViewModel()

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if viewModel.isLoading {
                DocumentSkeletonView()
            } else if viewModel.documents.isEmpty {
                DocumentEmptyStateView { viewModel.showFilePicker = true }
            } else {
                documentGrid
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.pdf]
        ) { result in
            Task { await viewModel.uploadDocument(result: result) }
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        // Modals
        .sheet(item: $viewModel.deleteTarget) { doc in
            DeleteConfirmSheet(
                document: doc,
                onConfirm: { Task { await viewModel.deleteDocument() } },
                onClose: { viewModel.deleteTarget = nil }
            )
        }
        .sheet(item: $viewModel.renameTarget) { doc in
            RenameSheet(
                document: doc,
                onConfirm: { name in Task { await viewModel.renameDocument(newFilename: name) } },
                onClose: { viewModel.renameTarget = nil }
            )
        }
        .sheet(item: $viewModel.detailsTarget) { doc in
            DetailsSheet(
                document: doc,
                onClose: { viewModel.detailsTarget = nil }
            )
        }
        .sheet(item: $viewModel.moveToCourseTarget) { doc in
            MoveToCourseSheet(
                document: doc,
                onConfirm: { courseId in Task { await viewModel.moveDocumentToCourse(courseId: courseId) } },
                onClose: { viewModel.moveToCourseTarget = nil }
            )
        }
        // Toast
        .overlay(alignment: .bottomTrailing) {
            if let message = viewModel.toastMessage {
                toastView(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(24)
            }
        }
        .animation(.spring(duration: 0.25), value: viewModel.toastMessage)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Documents")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(ReefColors.black)

                HStack(spacing: 10) {
                    Text("Upload and manage your study documents.")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.gray600)

                    if !viewModel.isLoading, let max = viewModel.maxDocuments {
                        let atLimit = viewModel.documents.count >= max
                        Text("\(viewModel.documents.count) / \(max)")
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(atLimit ? Color(hex: 0xC62828) : ReefColors.gray500)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(atLimit ? Color(hex: 0xFDECEA) : ReefColors.gray100)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if !viewModel.isLoading && !viewModel.documents.isEmpty {
                uploadButton
            }
        }
    }

    // MARK: - Upload Button

    private var uploadButton: some View {
        Button {
            viewModel.showFilePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 14, weight: .bold))
                Text("Upload")
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
            }
            .foregroundStyle(ReefColors.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(ReefColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ReefColors.black, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReefColors.black)
                    .offset(x: 4, y: 4)
            )
        }
    }

    // MARK: - Grid

    private var documentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                // Upload placeholder card
                Button {
                    viewModel.showFilePicker = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Upload")
                            .font(.epilogue(14, weight: .semiBold))
                            .tracking(-0.04 * 14)
                    }
                    .foregroundStyle(ReefColors.gray500)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .foregroundStyle(ReefColors.gray400)
                    )
                }
                .buttonStyle(.plain)
                .fadeUp(index: 0)

                // Document cards
                ForEach(Array(viewModel.documents.enumerated()), id: \.element.id) { index, doc in
                    DocumentCardView(
                        document: doc,
                        thumbnailURL: viewModel.thumbnailURLs[doc.id],
                        index: index + 1
                    ) { action in
                        handleAction(action, doc: doc)
                    }
                }
            }
        }
    }

    // MARK: - Action Handler

    private func handleAction(_ action: DocumentAction, doc: Document) {
        switch action {
        case .rename:
            viewModel.renameTarget = doc
        case .download:
            Task { await viewModel.downloadDocument(doc) }
        case .moveToCourse:
            viewModel.moveToCourseTarget = doc
        case .duplicate:
            Task { await viewModel.duplicateDocument(doc) }
        case .share:
            Task { await viewModel.shareDocument(doc) }
        case .viewDetails:
            viewModel.detailsTarget = doc
        case .delete:
            viewModel.deleteTarget = doc
        case .retry:
            Task { await viewModel.retryDocument(doc) }
        case .open:
            Task { await viewModel.openDocument(doc) }
        }
    }

    // MARK: - Toast

    private func toastView(message: String) -> some View {
        Text(message)
            .font(.epilogue(14, weight: .semiBold))
            .tracking(-0.04 * 14)
            .foregroundStyle(ReefColors.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(ReefColors.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
