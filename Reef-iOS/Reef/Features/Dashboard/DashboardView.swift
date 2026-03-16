import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
    @State private var viewModel = DashboardViewModel()

    private var metrics: ReefLayoutMetrics {
        ReefLayoutMetrics(
            screenHeight: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        )
    }

    var body: some View {
        ZStack {
            DottedBackground()
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                DashboardSidebar(viewModel: viewModel)

                VStack(spacing: 0) {
                    DashboardHeader(viewModel: viewModel)
                        .padding(.horizontal, 12)

                    contentArea
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 12)
        }
        .environment(\.layoutMetrics, metrics)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.sidebarOpen)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let tab = viewModel.selectedTab {
            tabPlaceholder(tab.label)
        } else if viewModel.selectedCourseId != nil {
            tabPlaceholder(viewModel.contentTitle)
        } else {
            tabPlaceholder("Dashboard")
        }
    }

    private func tabPlaceholder(_ title: String) -> some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 16) {
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
        .padding(32)
        .dashboardCard()
    }
}
