import SwiftUI

struct DashboardHeader: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    var viewModel: DashboardViewModel

    var body: some View {
        let colors = theme.colors
        HStack {
            // Breadcrumbs
            HStack(spacing: 8) {
                Text("Dashboard")
                    .font(.epilogue(16, weight: .semiBold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(colors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textDisabled)

                Text(viewModel.contentTitle)
                    .font(.epilogue(16, weight: .black))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(colors.text)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                // Search
                headerIcon("magnifyingglass")
                    .onTapGesture { viewModel.toggleDropdown(.search) }
                    .accessibilityLabel("Search")
                    .accessibilityAddTraits(.isButton)

                // Help
                headerIcon("questionmark.circle")
                    .onTapGesture { viewModel.toggleDropdown(.help) }
                    .accessibilityLabel("Help")
                    .accessibilityAddTraits(.isButton)

                // Notifications
                headerIcon("bell")
                    .onTapGesture { viewModel.toggleDropdown(.notifications) }
                    .accessibilityLabel("Notifications")
                    .accessibilityAddTraits(.isButton)

                // Dark mode toggle
                Image(systemName: theme.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            theme.isDarkMode.toggle()
                        }
                    }
                    .accessibilityLabel(theme.isDarkMode ? "Switch to light mode" : "Switch to dark mode")
                    .accessibilityAddTraits(.isButton)

                // Streak pill
                HStack(spacing: 4) {
                    Image("icon.streak")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(colors.text)
                    Text("0 days")
                        .font(.epilogue(13, weight: .semiBold))
                        .foregroundStyle(colors.text)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(colors.surface)
                .clipShape(Capsule())
                .reef3DPushCapsule(
                    shadowOffset: 2,
                    borderColor: colors.border,
                    shadowColor: colors.shadow
                ) {
                    // TODO: streak details
                }

                // Profile circle
                ZStack {
                    Circle()
                        .fill(ReefColors.accent)
                    Text(auth.userInitials)
                        .font(.epilogue(12, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(colors.border, lineWidth: 2))
                .background(
                    Circle()
                        .fill(colors.shadow)
                        .offset(x: 2, y: 2)
                )
                .contentShape(Circle())
                .onTapGesture { viewModel.toggleDropdown(.profile) }
                .accessibilityLabel("Profile menu")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: metrics.headerHeight)
        .padding(.horizontal, metrics.contentPadding)
        .dashboardCard()
        // Search dropdown
        .overlay(alignment: .topTrailing) {
            if viewModel.showSearch {
                comingSoonDropdown(icon: "magnifyingglass", text: "Search coming soon")
                    .offset(y: metrics.dropdownYOffset)
                    .padding(.trailing, metrics.notificationDropdownTrailing + 80)
                    .transition(dropdownTransition)
            }
        }
        // Help dropdown
        .overlay(alignment: .topTrailing) {
            if viewModel.showHelp {
                comingSoonDropdown(icon: "lifepreserver", text: "Help & support coming soon")
                    .offset(y: metrics.dropdownYOffset)
                    .padding(.trailing, metrics.notificationDropdownTrailing + 40)
                    .transition(dropdownTransition)
            }
        }
        // Notification dropdown
        .overlay(alignment: .topTrailing) {
            if viewModel.showNotifications {
                comingSoonDropdown(icon: "bell.slash", text: "No new notifications")
                    .offset(y: metrics.dropdownYOffset)
                    .padding(.trailing, metrics.notificationDropdownTrailing)
                    .transition(dropdownTransition)
            }
        }
        // Profile dropdown
        .overlay(alignment: .topTrailing) {
            if viewModel.showProfileMenu {
                ProfileDropdownMenu(viewModel: viewModel)
                    .offset(y: metrics.dropdownYOffset)
                    .padding(.trailing, metrics.dashboardHPadding)
                    .transition(dropdownTransition)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showProfileMenu)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showNotifications)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSearch)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showHelp)
    }

    // MARK: - Helpers

    private var dropdownTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)),
            removal: .opacity
        )
    }

    private func comingSoonDropdown(icon: String, text: String) -> some View {
        let colors = theme.colors
        let dark = theme.isDarkMode
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(colors.textMuted)

            Text(text)
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
        }
        .padding(.horizontal, metrics.dropdownItemHPadding)
        .padding(.vertical, metrics.dropdownItemVPadding)
        .background(colors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dark ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.Dark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
    }

    private func headerIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(theme.colors.textSecondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }
}
