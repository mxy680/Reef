import SwiftUI

struct DashboardSidebar: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    var viewModel: DashboardViewModel

    private var isOpen: Bool { viewModel.sidebarOpen }

    var body: some View {
        VStack(spacing: 0) {
            header
            navigation
            Spacer()
            footer
        }
        .frame(width: isOpen ? metrics.sidebarOpenWidth : metrics.sidebarCollapsedWidth)
        .frame(maxHeight: .infinity)
        .dashboardCard()
    }

    // MARK: - Header

    private var header: some View {
        let colors = theme.colors
        return HStack(spacing: 10) {
            if isOpen {
                Image("ReefLogo")
                    .resizable()
                    .frame(width: 28, height: 28)

                Text("REEF")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .textCase(.uppercase)
                    .foregroundStyle(colors.text)

                Spacer()
            }

            Image(systemName: "sidebar.left")
                .font(.system(size: 18))
                .foregroundStyle(colors.textSecondary)
                .frame(width: 28, height: 28)
                .compositingGroup()
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggleSidebar() }
                .accessibilityLabel("Toggle sidebar")
                .accessibilityAddTraits(.isButton)
        }
        .frame(height: metrics.headerHeight)
        .padding(.horizontal, metrics.sidebarHPadding)
    }

    // MARK: - Navigation

    private var navigation: some View {
        let colors = theme.colors
        return ScrollView {
            VStack(spacing: 2) {
                // Section header
                sectionHeader("WORKSPACE")

                ForEach(DashboardTab.mainTabs) { tab in
                    navItem(tab)
                }

                Rectangle()
                    .fill(colors.divider)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                coursesSection
            }
            .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : metrics.sidebarItemHPaddingCollapsed)
            .padding(.top, metrics.sidebarNavTopPadding)
            .padding(.trailing, 3) // Room for 3D shadow offset
        }
    }

    // MARK: - Courses Section (stub)

    private var coursesSection: some View {
        let colors = theme.colors
        return VStack(spacing: 2) {
            HStack {
                if isOpen {
                    Text("COURSES")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(0.06 * 11)
                        .foregroundStyle(colors.textDisabled)

                    Spacer()
                }

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colors.textDisabled)
                    .frame(width: 24, height: 24)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture { /* Stub — course creation wired later */ }
                    .accessibilityLabel("Add course")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : 0)
            .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)

            // Empty state
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)

                if isOpen {
                    Text("Add a course")
                        .font(.epilogue(15, weight: .semiBold))
                        .tracking(-0.04 * 15)
                }
            }
            .foregroundStyle(colors.textDisabled)
            .padding(.vertical, 8)
            .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : 0)
            .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { /* Stub */ }
            .accessibilityLabel("Add a course")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Nav Item

    private func navItem(_ tab: DashboardTab) -> some View {
        let isActive = viewModel.selectedTab == tab
        let colors = theme.colors

        return HStack(spacing: 12) {
            Image(tab.icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            if isOpen {
                Text(tab.label)
                    .font(.epilogue(15, weight: isActive ? .bold : .semiBold))
                    .tracking(-0.04 * 15)

                Spacer()
            }
        }
        .foregroundStyle(isActive ? colors.text : colors.textSecondary)
        .padding(.vertical, 8)
        .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : 0)
        .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
        .background(
            isActive
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(colors.activeNavBg)
                : nil
        )
        .overlay(
            isActive
                ? RoundedRectangle(cornerRadius: 10)
                    .stroke(colors.activeNavBorder, lineWidth: 2)
                : nil
        )
        .background(
            isActive
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(colors.shadow)
                    .offset(x: 3, y: 3)
                : nil
        )
        .compositingGroup()
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { viewModel.selectTab(tab) }
        .accessibilityIdentifier("sidebar.tab.\(tab.rawValue)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Footer

    private var footer: some View {
        let colors = theme.colors
        return VStack(spacing: 0) {
            // Upgrade
            footerRow {
                circleIcon(fill: ReefColors.accent) {
                    Image("icon.upgrade")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(ReefColors.black)
                }
            } label: {
                Text("Upgrade")
            } trailing: {
                Text("FREE BETA")
                    .font(.epilogue(10, weight: .black))
                    .tracking(0.02 * 10)
                    .textCase(.uppercase)
                    .foregroundStyle(colors.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(colors.border, lineWidth: 2)
                    )
            }
            .onTapGesture { /* TODO: Navigate to upgrade/billing */ }
            .accessibilityAddTraits(.isButton)

            // Settings
            footerRow {
                circleIcon(fill: colors.subtle) {
                    Image("icon.settings")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(colors.text)
                }
            } label: {
                Text("Settings")
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textDisabled)
            }
            .onTapGesture { viewModel.selectTab(.settings) }
            .accessibilityAddTraits(.isButton)

            // User
            footerRow {
                circleIcon(fill: colors.surface) {
                    Text(auth.userInitials)
                        .font(.epilogue(12, weight: .black))
                        .foregroundStyle(colors.text)
                }
            } label: {
                Text(auth.displayName)
                    .lineLimit(1)
            } trailing: {
                Image("icon.settings")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(colors.textDisabled)
            }
            .onTapGesture { viewModel.selectTab(.settings) }
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : metrics.sidebarItemHPaddingCollapsed)
        .padding(.bottom, metrics.sidebarFooterBottomPadding)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            if isOpen {
                Text(title)
                    .font(.epilogue(11, weight: .bold))
                    .tracking(0.06 * 11)
                    .foregroundStyle(theme.colors.textDisabled)

                Spacer()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isOpen ? metrics.sidebarItemHPadding : 0)
        .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
    }

    private func circleIcon<Content: View>(
        fill: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle().stroke(theme.colors.border, lineWidth: 2)
                )
            content()
        }
    }

    private func footerRow<Icon: View, Label: View, Trailing: View>(
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let colors = theme.colors
        return HStack(spacing: 10) {
            icon()

            if isOpen {
                label()
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)

                Spacer()

                trailing()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isOpen ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
        .compositingGroup()
        .contentShape(Rectangle())
    }
}
