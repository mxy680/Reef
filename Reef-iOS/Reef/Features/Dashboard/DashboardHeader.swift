import SwiftUI

struct DashboardHeader: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    var viewModel: DashboardViewModel

    private static let gradeLabels: [String: String] = [
        "middle_school": "Middle School",
        "high_school": "High School",
        "college": "College",
        "graduate": "Graduate",
        "other": "Other",
    ]

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
                // TODO: Wire search and help actions — currently non-interactive
                headerIcon("magnifyingglass")
                headerIcon("questionmark.circle")

                // Bell with notification dot
                ZStack(alignment: .topTrailing) {
                    headerIcon("bell")
                    // TODO: Conditionally show based on unread notification count
                    Circle()
                        .fill(Color(hex: 0xE74C3C))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(colors.card, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }

                // Dark mode toggle
                Image(systemName: theme.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .compositingGroup()
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
                .reef3DPushCircle(
                    borderColor: colors.border,
                    shadowColor: colors.shadow
                ) {
                    viewModel.toggleProfileMenu()
                }
            }
        }
        .frame(height: metrics.headerHeight)
        .padding(.horizontal, metrics.contentPadding)
        .dashboardCard()
    }

    // MARK: - Profile Dropdown (rendered by DashboardView)

    var profileDropdownMenu: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 0) {
            // User info
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ReefColors.accent)
                        .frame(width: 32, height: 32)
                    Text(auth.userInitials)
                        .font(.epilogue(11, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(auth.displayName)
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)
                        .lineLimit(1)

                    Text(auth.session?.email ?? "")
                        .font(.epilogue(11, weight: .medium))
                        .tracking(-0.02 * 11)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Grade + Tier pill
            HStack(spacing: 8) {
                if let grade = auth.profile?.grade, let label = Self.gradeLabels[grade] {
                    Text(label)
                        .font(.epilogue(12, weight: .semiBold))
                        .tracking(-0.02 * 12)
                        .foregroundStyle(colors.textSecondary)
                }

                // TODO: Replace with dynamic tier from user subscription state
                Text("Shore · Free")
                    .font(.epilogue(11, weight: .bold))
                    .tracking(-0.02 * 11)
                    .foregroundStyle(ReefColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ReefColors.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // Streak
            HStack(spacing: 4) {
                Image("icon.streak")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(colors.textSecondary)
                Text("0 day streak")
                    .font(.epilogue(12, weight: .semiBold))
                    .tracking(-0.02 * 12)
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            dropdownDivider

            profileMenuItem(icon: "person.crop.circle", label: "Edit Profile") {
                viewModel.dismissProfileMenu()
                viewModel.selectTab(.settings)
            }
            profileMenuItem(icon: "slider.horizontal.3", label: "Preferences") {
                viewModel.dismissProfileMenu()
                viewModel.selectTab(.settings)
            }
            profileMenuItem(icon: "questionmark.circle", label: "Help & Support") {
                viewModel.dismissProfileMenu()
            }

            dropdownDivider

            profileMenuItem(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", isDestructive: true) {
                viewModel.dismissProfileMenu()
                Task { await auth.signOut() }
            }
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
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 220, alignment: .trailing)
    }

    // MARK: - Helpers

    private var dropdownDivider: some View {
        Rectangle()
            .fill(theme.colors.divider)
            .frame(height: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
    }

    private func profileMenuItem(
        icon: String,
        label: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let colors = theme.colors
        return Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : colors.textSecondary)
                    .frame(width: 18)

                Text(label)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : colors.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func headerIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(theme.colors.textSecondary)
            .frame(width: 32, height: 32)
    }
}
