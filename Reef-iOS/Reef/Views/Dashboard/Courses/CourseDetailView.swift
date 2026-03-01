import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class CourseDetailViewModel {
    var course: Course
    var documents: [Document] = []
    var thumbnailURLs: [String: URL] = [:]
    var isLoading = true
    var toastMessage: String?

    var showDelete = false
    var showEdit = false

    init(course: Course) {
        self.course = course
    }

    // MARK: - Fetch

    func fetchData() async {
        do {
            let docs = try await CourseService.shared.listDocumentsForCourse(course.id)
            documents = docs

            if !docs.isEmpty {
                let urls = try await DocumentService.shared.getThumbnailURLs(docs.map(\.id))
                thumbnailURLs.merge(urls) { _, new in new }
            }
        } catch {
            print("Failed to fetch course documents: \(error)")
        }
        isLoading = false
    }

    // MARK: - Actions

    func deleteCourse() async -> Bool {
        do {
            try await CourseService.shared.deleteCourse(course.id)
            return true
        } catch {
            showToast("Something went wrong")
            return false
        }
    }

    func updateCourse(name: String, emoji: String) async -> Bool {
        do {
            try await CourseService.shared.updateCourse(course.id, name: name, emoji: emoji)
            course = Course(id: course.id, userId: course.userId, name: name, emoji: emoji, color: course.color, createdAt: course.createdAt)
            showToast("Course updated")
            return true
        } catch {
            showToast("Something went wrong")
            return false
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

struct CourseDetailView: View {
    let courseId: String
    let initialCourse: Course
    let onCourseDeleted: () -> Void
    let onCourseUpdated: () -> Void

    @State private var viewModel: CourseDetailViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    init(courseId: String, course: Course, onCourseDeleted: @escaping () -> Void, onCourseUpdated: @escaping () -> Void) {
        self.courseId = courseId
        self.initialCourse = course
        self.onCourseDeleted = onCourseDeleted
        self.onCourseUpdated = onCourseUpdated
        self._viewModel = State(initialValue: CourseDetailViewModel(course: course))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if viewModel.isLoading {
                DocumentSkeletonView()
            } else if viewModel.documents.isEmpty {
                emptyState
            } else {
                documentGrid
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
        .task { await viewModel.fetchData() }
        .id(courseId)
        // Modals
        .overlay {
            if viewModel.showDelete || viewModel.showEdit {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showDelete = false
                            viewModel.showEdit = false
                        }
                    }

                if viewModel.showDelete {
                    DeleteCourseSheet(
                        course: viewModel.course,
                        onConfirm: {
                            Task {
                                if await viewModel.deleteCourse() {
                                    onCourseDeleted()
                                }
                            }
                        },
                        onClose: {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.showDelete = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .padding(32)
                }

                if viewModel.showEdit {
                    EditCourseSheet(
                        course: viewModel.course,
                        onConfirm: { name, emoji in
                            Task {
                                if await viewModel.updateCourse(name: name, emoji: emoji) {
                                    withAnimation(.spring(duration: 0.2)) {
                                        viewModel.showEdit = false
                                    }
                                    onCourseUpdated()
                                }
                            }
                        },
                        onClose: {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.showEdit = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .padding(32)
                }
            }
        }
        .animation(.spring(duration: 0.2), value: viewModel.showDelete)
        .animation(.spring(duration: 0.2), value: viewModel.showEdit)
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
            HStack(spacing: 10) {
                Text(viewModel.course.emoji)
                    .font(.system(size: 28))

                Text(viewModel.course.name)
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(ReefColors.black)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.2)) { viewModel.showEdit = true }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ReefColors.gray600)
                        .frame(width: 36, height: 36)
                        .background(ReefColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ReefColors.gray400, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(duration: 0.2)) { viewModel.showDelete = true }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xC62828))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: 0xFFF5F5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: 0xE57373), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(ReefColors.gray400)

            Text("No documents in this course")
                .font(.epilogue(16, weight: .semiBold))
                .tracking(-0.04 * 16)
                .foregroundStyle(ReefColors.gray500)

            Text("Move documents here from the Documents tab.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private var documentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(viewModel.documents.enumerated()), id: \.element.id) { index, doc in
                    DocumentCardView(
                        document: doc,
                        thumbnailURL: viewModel.thumbnailURLs[doc.id],
                        index: index
                    ) { action in
                        if case .open = action {
                            Task { await viewModel.openDocument(doc) }
                        }
                    }
                }
            }
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
