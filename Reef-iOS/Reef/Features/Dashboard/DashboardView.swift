import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    @State private var viewModel = DashboardViewModel()
    @State private var documentsVM = DocumentsViewModel()
    @State private var canvasDocument: Document?

    var body: some View {
        ZStack {
            DottedBackground()
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                DashboardSidebar(viewModel: viewModel)

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: metrics.headerHeight + metrics.headerGap)

                        contentArea
                            .padding(.horizontal, metrics.dashboardHPadding)
                    }
                    // Dismiss backdrop covers content + sidebar but NOT header
                    .overlay {
                        if anyDropdownOpen {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.dismissAllDropdowns() }
                        }
                    }

                    DashboardHeader(viewModel: viewModel)
                        .padding(.horizontal, metrics.dashboardHPadding)
                }
            }
            .padding(.horizontal, metrics.dashboardHPadding)

            // MARK: - Document Modal Overlays

            if documentsVM.deleteTarget != nil || documentsVM.renameTarget != nil
                || documentsVM.detailsTarget != nil || documentsVM.moveToCourseTarget != nil
                || documentsVM.pendingUploadURL != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.deleteTarget = nil
                            documentsVM.renameTarget = nil
                            documentsVM.detailsTarget = nil
                            documentsVM.moveToCourseTarget = nil
                            documentsVM.pendingUploadURL = nil
                        }
                    }
            }

            if let doc = documentsVM.deleteTarget {
                DeleteConfirmPopup(document: doc) {
                    Task { await documentsVM.deleteDocument() }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.deleteTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.deleteTarget != nil)
            }

            if let doc = documentsVM.renameTarget {
                RenamePopup(document: doc) { newFilename in
                    Task { await documentsVM.renameDocument(newFilename: newFilename) }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.renameTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.renameTarget != nil)
            }

            if let doc = documentsVM.detailsTarget {
                DetailsPopup(document: doc) {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.detailsTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.detailsTarget != nil)
            }

            if let doc = documentsVM.moveToCourseTarget {
                MoveToCoursePopup(document: doc) { courseId in
                    Task { await documentsVM.moveDocumentToCourse(courseId: courseId) }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.moveToCourseTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.moveToCourseTarget != nil)
            }

            if let url = documentsVM.pendingUploadURL {
                DocumentUploadPopup(filename: url.lastPathComponent) { courseId, reconstruct in
                    documentsVM.performUploadWithOptions(courseId: courseId, reconstruct: reconstruct)
                    withAnimation(.spring(duration: 0.2)) { }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.pendingUploadURL = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.pendingUploadURL != nil)
            }
            // MARK: - Canvas Fullscreen Overlay

            if let doc = canvasDocument {
                CanvasView(
                    viewModel: CanvasViewModel(document: doc),
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            canvasDocument = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: canvasDocument?.id)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.sidebarOpen)
        .alert(
            "Error",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )
        ) {
            Button("OK") { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    private var anyDropdownOpen: Bool {
        viewModel.showProfileMenu || viewModel.showNotifications || viewModel.showSearch || viewModel.showHelp
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let tab = viewModel.selectedTab {
            switch tab {
            case .documents:
                DocumentsContentView(viewModel: documentsVM, onOpenCanvas: { doc in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        canvasDocument = doc
                    }
                })
            case .analytics:
                AnalyticsView()
            case .myReef:
                ComingSoonView(
                    icon: "water.waves",
                    title: "Your reef is growing",
                    subtitle: "Track your marine species collection as you master new topics."
                )
            case .tutors:
                ComingSoonView(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "Your crew is assembling",
                    subtitle: "AI tutors that guide you through every problem, coming soon."
                )
            case .library:
                ComingSoonView(
                    icon: "books.vertical",
                    title: "Deep waters ahead",
                    subtitle: "A shared library of study materials from your courses."
                )
            case .settings:
                SettingsView()
            default:
                tabPlaceholder(tab.label)
            }
        } else if viewModel.selectedCourseId != nil {
            tabPlaceholder(viewModel.contentTitle)
        } else {
            // Fallback — should not happen (selectedTab defaults to .documents)
            tabPlaceholder("Dashboard")
        }
    }

    private func tabPlaceholder(_ title: String) -> some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            Text(title)
                .font(.epilogue(28, weight: .black))
                .tracking(-0.04 * 28)
                .foregroundStyle(colors.text)

            Text("Coming soon")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.contentPadding)
        .dashboardCard()
    }
}
