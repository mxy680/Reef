import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
    @State private var viewModel = DashboardViewModel()

    private let metrics = ReefLayoutMetrics(
        screenHeight: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    )

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

            // Dropdown overlays — rendered in root ZStack above everything
            dropdownOverlays
        }
        .environment(\.reefLayoutMetrics, metrics)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.sidebarOpen)
    }

    // MARK: - Dropdown Overlays

    private var anyDropdownOpen: Bool {
        viewModel.showProfileMenu || viewModel.showNotifications
    }

    @ViewBuilder
    private var dropdownOverlays: some View {
        if anyDropdownOpen {
            // Dismiss backdrop
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showProfileMenu = false
                    viewModel.showNotifications = false
                }
                .transition(.opacity)

            // Position dropdowns at top-right, below the header
            VStack {
                HStack {
                    Spacer()

                    if viewModel.showNotifications {
                        notificationsDropdown
                            .padding(.trailing, 200)
                    }

                    if viewModel.showProfileMenu {
                        ProfileDropdownMenu(viewModel: viewModel)
                    }
                }
                .padding(.top, metrics.headerHeight + 24)
                .padding(.trailing, 24)

                Spacer()
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)),
                removal: .opacity
            ))
        }
    }

    private var notificationsDropdown: some View {
        let colors = theme.colors
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.textMuted)

                Text("No new notifications")
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(colors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.isDarkMode ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.isDarkMode ? ReefColors.Dark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
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
