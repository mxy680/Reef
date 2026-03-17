import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    @State private var viewModel = DashboardViewModel()

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
        }
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
            tabPlaceholder(tab.label)
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
