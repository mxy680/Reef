import SwiftUI

struct DashboardHeader: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    var viewModel: DashboardViewModel

    var body: some View {
        @Bindable var vm = viewModel
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
                // TODO: Wire search and help actions
                headerIcon("magnifyingglass")
                headerIcon("questionmark.circle")

                // Notifications bell
                headerIcon("bell")
                    .onTapGesture { viewModel.showNotifications.toggle() }
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
                .onTapGesture { viewModel.showProfileMenu.toggle() }
                .accessibilityLabel("Profile menu")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: metrics.headerHeight)
        .padding(.horizontal, metrics.contentPadding)
        .dashboardCard()
        // Dismiss backdrop
        .overlay {
            if anyDropdownOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.showNotifications = false
                        viewModel.showProfileMenu = false
                    }
                    .transition(.opacity)
            }
        }
        // Dropdown overlays
        .overlay(alignment: .topTrailing) {
            if viewModel.showNotifications {
                notificationsDropdown(colors)
                    .offset(y: 68)
                    .padding(.trailing, 180)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)),
                        removal: .opacity
                    ))
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.showProfileMenu {
                ProfileDropdownMenu(viewModel: viewModel)
                    .offset(y: 68)
                    .padding(.trailing, 12)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showProfileMenu)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showNotifications)
    }

    private var anyDropdownOpen: Bool {
        viewModel.showProfileMenu || viewModel.showNotifications
    }

    // MARK: - Notifications Dropdown

    private func notificationsDropdown(_ colors: ReefThemeColors) -> some View {
        let dark = theme.isDarkMode
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
                .stroke(dark ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.Dark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
    }

    // MARK: - Helpers

    private func headerIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(theme.colors.textSecondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }
}
