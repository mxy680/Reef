import SwiftUI

struct DashboardHeader: View {
    let title: String
    @Binding var selectedTab: DashboardTab?
    @Binding var selectedCourseId: String?
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var theme
    @State private var showProfileMenu = false
    @Environment(\.layoutMetrics) private var metrics

    private let gradeLabels: [String: String] = [
        "middle_school": "Middle School",
        "high_school": "High School",
        "college": "College",
        "graduate": "Graduate",
        "other": "Other",
    ]

    var body: some View {
        let dark = theme.isDarkMode
        HStack {
            // Breadcrumbs
            HStack(spacing: 8) {
                Text("Dashboard")
                    .font(.epilogue(16, weight: .semiBold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400)

                Text(title)
                    .font(.epilogue(16, weight: .black))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                headerIcon("magnifyingglass")
                headerIcon("questionmark.circle")

                // Bell with notification dot
                ZStack(alignment: .topTrailing) {
                    headerIcon("bell")
                    Circle()
                        .fill(Color(hex: 0xE74C3C))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(dark ? ReefColors.DashboardDark.card : ReefColors.white, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }

                // Dark mode toggle
                Image(systemName: dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                    .frame(width: 32, height: 32)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            theme.isDarkMode.toggle()
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(dark ? "Switch to light mode" : "Switch to dark mode")

                // Streak pill
                HStack(spacing: 4) {
                    Image("icon.streak")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                    Text("0 days")
                        .font(.epilogue(13, weight: .semiBold))
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(dark ? ReefColors.DashboardDark.surface : ReefColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5))
                .background(
                    Capsule()
                        .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
                        .offset(x: 2, y: 2)
                )

                // Profile circle
                ZStack {
                    Circle()
                        .fill(ReefColors.accent)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5))
                        .background(
                            Circle()
                                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
                                .frame(width: 32, height: 32)
                                .offset(x: 2, y: 2)
                        )
                    Text(userInitials)
                        .font(.epilogue(12, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) {
                        showProfileMenu.toggle()
                    }
                }
            }
        }
        .frame(height: metrics.headerHeight)
        .padding(.horizontal, metrics.contentPadding)
        .dashboardCard()
        .overlay(alignment: .topTrailing) {
            if showProfileMenu {
                // Dismiss backdrop
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            showProfileMenu = false
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showProfileMenu {
                profileDropdownMenu
                    .offset(y: 68)
                    .padding(.trailing, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .zIndex(showProfileMenu ? 10 : 0)
    }

    // MARK: - Dropdown Menu

    private var profileDropdownMenu: some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 0) {
            // User info
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ReefColors.accent)
                        .frame(width: 32, height: 32)
                    Text(userInitials)
                        .font(.epilogue(11, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                        .lineLimit(1)

                    Text(userEmail)
                        .font(.epilogue(11, weight: .medium))
                        .tracking(-0.02 * 11)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Grade + Tier pill
            HStack(spacing: 8) {
                if !userGrade.isEmpty {
                    Text(userGrade)
                        .font(.epilogue(12, weight: .semiBold))
                        .tracking(-0.02 * 12)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                }

                Text(tierLabel)
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
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                Text("0 day streak")
                    .font(.epilogue(12, weight: .semiBold))
                    .tracking(-0.02 * 12)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Divider
            Rectangle()
                .fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100)
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 2)

            // Edit Profile
            profileMenuItem(icon: "person.crop.circle", label: "Edit Profile") {
                showProfileMenu = false
                selectedTab = .settings
                selectedCourseId = nil
            }

            // Preferences
            profileMenuItem(icon: "slider.horizontal.3", label: "Preferences") {
                showProfileMenu = false
                selectedTab = .settings
                selectedCourseId = nil
            }

            // Help & Support
            profileMenuItem(icon: "questionmark.circle", label: "Help & Support") {
                showProfileMenu = false
            }

            // Divider
            Rectangle()
                .fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100)
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 2)

            // Log Out
            profileMenuItem(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", isDestructive: true) {
                showProfileMenu = false
                authManager.signOut()
            }
        }
        .background(dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 220, alignment: .trailing)
    }

    private func profileMenuItem(icon: String, label: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        let dark = theme.isDarkMode
        return Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : (dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600))
                    .frame(width: 18)

                Text(label)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func headerIcon(_ icon: String, isCustom: Bool = false) -> some View {
        Group {
            if isCustom {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 18))
            }
        }
        .foregroundStyle(theme.isDarkMode ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
        .frame(width: 32, height: 32)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityAddTraits(.isButton)
    }

    private var displayName: String {
        if let meta = authManager.session?.user.userMetadata["display_name"],
           case .string(let name) = meta {
            return name
        }
        return authManager.session?.user.email?.components(separatedBy: "@").first ?? "User"
    }

    private var userEmail: String {
        authManager.session?.user.email ?? ""
    }

    private var userGrade: String {
        if let profile = authManager.profile,
           let grade = profile.grade {
            return gradeLabels[grade] ?? grade
        }
        return ""
    }

    private var tierLabel: String {
        "Shore · Free"
    }

    private var userInitials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
