import SwiftUI

/// Profile dropdown menu — extracted as a standalone view so it can be
/// placed in DashboardView's root ZStack with proper @Environment access.
struct ProfileDropdownMenu: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
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
        VStack(alignment: .leading, spacing: 0) {
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

            dividerLine

            menuItem(icon: "person.crop.circle", label: "Edit Profile") {
                viewModel.dismissProfileMenu()
                viewModel.selectTab(.settings)
            }
            menuItem(icon: "slider.horizontal.3", label: "Preferences") {
                viewModel.dismissProfileMenu()
                viewModel.selectTab(.settings)
            }
            menuItem(icon: "questionmark.circle", label: "Help & Support") {
                viewModel.dismissProfileMenu()
            }

            dividerLine

            menuItem(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", isDestructive: true) {
                viewModel.dismissProfileMenu()
                Task { await auth.signOut() }
            }
        }
    }

    // MARK: - Helpers

    private var dividerLine: some View {
        Rectangle()
            .fill(theme.colors.divider)
            .frame(height: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
    }

    private func menuItem(
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
}
