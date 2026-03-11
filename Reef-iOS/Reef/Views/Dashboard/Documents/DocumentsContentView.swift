import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct DocumentsContentView: View {
    @Bindable var viewModel: DocumentsViewModel
    var onOpenCanvas: ((Document) -> Void)?
    @Environment(\.layoutMetrics) private var metrics
    @Environment(ThemeManager.self) private var theme

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: metrics.gridColumnMin, maximum: metrics.gridColumnMax), spacing: 28)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if viewModel.isLoading {
                DocumentSkeletonView()
                Spacer()
            } else if viewModel.documents.isEmpty {
                DocumentEmptyStateView { viewModel.showFilePicker = true }
                Spacer()
            } else {
                documentGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.cardPadding)
        .dashboardCard()
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.pdf]
        ) { result in
            viewModel.uploadDocument(result: result)
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
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
        let dark = theme.isDarkMode
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Documents")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                HStack(spacing: 10) {
                    Text("Upload and manage your study documents.")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                    if !viewModel.isLoading, let max = viewModel.maxDocuments {
                        let atLimit = viewModel.documents.count >= max
                        Text("\(viewModel.documents.count) / \(max)")
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(atLimit ? Color(hex: 0xC62828) : (dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(atLimit ? Color(hex: 0xFDECEA) : (dark ? ReefColors.DashboardDark.subtle : ReefColors.gray100))
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
        let dark = theme.isDarkMode
        return HStack(spacing: 8) {
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
        .reef3DPush(
            cornerRadius: 10,
            borderColor: dark ? ReefColors.DashboardDark.border : ReefColors.black,
            shadowColor: dark ? ReefColors.DashboardDark.shadow : ReefColors.black
        ) {
            viewModel.showFilePicker = true
        }
    }

    // MARK: - Grid

    private let rowSpacing: CGFloat = 24
    private let shadowPad: CGFloat = 4
    private let gridPadH: CGFloat = 16
    private let gridPadV: CGFloat = 12

    private var documentGrid: some View {
        let dark = theme.isDarkMode
        return GeometryReader { geo in
            let cardHeight = (geo.size.height - rowSpacing - shadowPad - gridPadV * 2) / 2

            ScrollView {
                LazyVGrid(columns: columns, spacing: rowSpacing) {

                    // Upload placeholder card — height matches document cards
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Upload")
                            .font(.epilogue(14, weight: .semiBold))
                            .tracking(-0.04 * 14)
                    }
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: cardHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400)
                    )
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.showFilePicker = true
                    }
                    .accessibilityAddTraits(.isButton)
                    .fadeUp(index: 0)

                    // Document cards
                    ForEach(Array(viewModel.documents.enumerated()), id: \.element.id) { index, doc in
                        DocumentCardView(
                            document: doc,
                            thumbnailURL: viewModel.thumbnailURLs[doc.id],
                            index: index + 1,
                            cardHeight: cardHeight
                        ) { action in
                            handleAction(action, doc: doc)
                        }
                    }
                }
                .padding([.trailing, .bottom], shadowPad)
                .padding(.horizontal, gridPadH)
                .padding(.vertical, gridPadV)
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
            if doc.status == .completed {
                onOpenCanvas?(doc)
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
