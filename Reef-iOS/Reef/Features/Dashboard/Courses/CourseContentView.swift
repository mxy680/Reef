import SwiftUI

struct CourseContentView: View {
    let course: Course
    let onOpenCanvas: (Document) -> Void
    let onEditTapped: () -> Void
    let onDeleteTapped: () -> Void

    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @State private var documents: [Document] = []
    @State private var thumbnailURLs: [String: URL] = [:]
    @State private var isLoading = true

    private let docRepo: DocumentRepository = SupabaseDocumentRepository()

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: metrics.gridColumnMin, maximum: metrics.gridColumnMax), spacing: metrics.gridRowSpacing)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if isLoading {
                DocumentSkeletonView()
                Spacer()
            } else if documents.isEmpty {
                courseEmptyState
                Spacer()
            } else {
                documentGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.cardPadding)
        .dashboardCard()
        .task { await fetchDocuments() }
    }

    // MARK: - Header

    private var headerRow: some View {
        let colors = theme.colors
        return HStack(alignment: .top) {
            HStack(spacing: 10) {
                Image(course.emoji)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundStyle(colors.textSecondary)

                Text(course.name)
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(colors.text)
            }

            Spacer()

            HStack(spacing: 8) {
                ReefModalButton("Edit", variant: .secondary) {
                    onEditTapped()
                }

                ReefModalButton("Delete", variant: .destructive) {
                    onDeleteTapped()
                }
            }
        }
    }

    // MARK: - Empty State

    private var courseEmptyState: some View {
        let colors = theme.colors
        return VStack(spacing: 12) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(colors.textDisabled)

            Text("No documents in this course")
                .font(.epilogue(16, weight: .semiBold))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.textMuted)

            Text("Move documents here from the Documents tab.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textDisabled)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private let shadowPad: CGFloat = 4

    private var documentGrid: some View {
        GeometryReader { geo in
            let cardHeight = (geo.size.height - metrics.gridRowSpacing - shadowPad - metrics.gridPadV * 2) / 2

            ScrollView {
                LazyVGrid(columns: columns, spacing: metrics.gridRowSpacing) {
                    ForEach(Array(documents.enumerated()), id: \.element.id) { index, doc in
                        DocumentCardView(
                            document: doc,
                            thumbnailURL: thumbnailURLs[doc.id],
                            index: index,
                            cardHeight: cardHeight
                        ) { action in
                            if case .open = action, doc.status == .completed {
                                onOpenCanvas(doc)
                            }
                        }
                    }
                }
                .padding([.trailing, .bottom], shadowPad)
                .padding(.horizontal, metrics.gridPadH)
                .padding(.vertical, metrics.gridPadV)
            }
        }
    }

    // MARK: - Data Fetching

    private func fetchDocuments() async {
        do {
            let all = try await docRepo.listDocuments()
            let filtered = all.filter { $0.courseId == course.id }
            documents = filtered

            if !filtered.isEmpty {
                let urls = try await docRepo.getThumbnailURLs(filtered.map(\.id))
                thumbnailURLs = urls
            }
        } catch {
            // Surface no documents on error — retrying is handled at the parent level
        }
        isLoading = false
    }
}
