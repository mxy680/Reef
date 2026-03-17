import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
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

                    DashboardHeader(viewModel: viewModel)
                        .padding(.horizontal, metrics.dashboardHPadding)
                }
            }
            .padding(.horizontal, metrics.dashboardHPadding)

            // Dropdown overlays — root ZStack, always above content
            dropdownOverlays
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.sidebarOpen)
    }

    // MARK: - Dropdown Overlays

    private var anyDropdownOpen: Bool {
        viewModel.showProfileMenu || viewModel.showNotifications || viewModel.showSearch || viewModel.showHelp
    }

    @ViewBuilder
    private var dropdownOverlays: some View {
        if anyDropdownOpen {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showProfileMenu = false
                    viewModel.showNotifications = false
                    viewModel.showSearch = false
                    viewModel.showHelp = false
                }
                .transition(.opacity)
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let tab = viewModel.selectedTab {
            tabPlaceholder(tab.label)
        } else if viewModel.selectedCourseId != nil {
            tabPlaceholder(viewModel.contentTitle)
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
