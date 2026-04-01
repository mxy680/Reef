import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct DocumentsContentView: View {
    @Bindable var viewModel: DocumentsViewModel
    var onOpenCanvas: ((Document) -> Void)?
    @Environment(\.reefLayoutMetrics) private var metrics
    @Environment(ReefTheme.self) private var theme

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: metrics.gridColumnMin, maximum: metrics.gridColumnMax), spacing: 28)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if viewModel.isLoading {
                DocumentSkeletonView()
                Spacer()
            } else if let error = viewModel.loadError {
                errorStateView(error)
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
        let colors = theme.colors
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Documents")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(colors.text)

                HStack(spacing: 10) {
                    Text("Upload and manage your study documents.")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.textSecondary)

                    if !viewModel.isLoading, let max = viewModel.maxDocuments {
                        let atLimit = viewModel.documents.count >= max
                        Text("\(viewModel.documents.count) / \(max)")
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(atLimit ? ReefColors.destructive : colors.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(atLimit ? Color(hex: 0xFDECEA) : colors.subtle)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if !viewModel.isLoading && !viewModel.documents.isEmpty {
                newButton
            }
        }
    }

    // MARK: - New Button (Upload or Generate)

    private var newButton: some View {
        let colors = theme.colors
        return Menu {
            Button {
                viewModel.showFilePicker = true
            } label: {
                Label("Upload PDF", systemImage: "arrow.up.doc")
            }
            Button {
                viewModel.showGenerateQuestion = true
            } label: {
                Label("Generate Problem", systemImage: "sparkles")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New")
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
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.shadow)
                    .offset(x: 3, y: 3)
            )
        }
    }

    // MARK: - Grid

    private let shadowPad: CGFloat = 4 // decorative, fixed

    private var documentGrid: some View {
        let colors = theme.colors
        return GeometryReader { geo in
            let cardHeight = (geo.size.height - metrics.gridRowSpacing - shadowPad - metrics.gridPadV * 2) / 2

            ScrollView {
                LazyVGrid(columns: columns, spacing: metrics.gridRowSpacing) {

                    // New document placeholder card — dashed border, menu on tap
                    Menu {
                        Button {
                            viewModel.showFilePicker = true
                        } label: {
                            Label("Upload PDF", systemImage: "arrow.up.doc")
                        }
                        Button {
                            viewModel.showGenerateQuestion = true
                        } label: {
                            Label("Generate Problem", systemImage: "sparkles")
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                            Text("New")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                        }
                        .foregroundStyle(colors.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: cardHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                                .foregroundStyle(colors.textDisabled)
                        )
                    }
                    .compositingGroup()
                    .accessibilityAddTraits(.isButton)
                    .fadeUp(index: 0)

                    // Document cards
                    ForEach(Array(viewModel.documents.enumerated()), id: \.element.id) { index, doc in
                        DocumentCardView(
                            document: doc,
                            thumbnailURL: viewModel.thumbnailURLs[doc.id],
                            index: index,
                            cardHeight: cardHeight
                        ) { action in
                            handleAction(action, doc: doc)
                        }
                    }
                }
                .padding([.trailing, .bottom], shadowPad)
                .padding(.horizontal, metrics.gridPadH)
                .padding(.vertical, metrics.gridPadV)
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

    private func errorStateView(_ message: String) -> some View {
        let colors = theme.colors
        return VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(colors.textDisabled)
            Text(message)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
            ReefButton("Retry", variant: .secondary, size: .compact) {
                Task { await viewModel.fetchDocuments() }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
