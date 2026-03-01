import SwiftUI

struct DashboardSidebar: View {
    @Binding var selectedTab: DashboardTab
    @Binding var isOpen: Bool
    @Environment(AuthManager.self) private var authManager

    static let openWidth: CGFloat = 260
    static let collapsedWidth: CGFloat = 68

    var width: CGFloat {
        isOpen ? Self.openWidth : Self.collapsedWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            navigation
            Spacer()
            footer
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .dashboardCard()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            if isOpen {
                MantaRayShape()
                    .fill(ReefColors.primary)
                    .frame(width: 24, height: 24)

                Text("REEF")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .textCase(.uppercase)
                    .foregroundStyle(ReefColors.black)

                Spacer()
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    isOpen.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundStyle(ReefColors.gray600)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 64)
        .padding(.horizontal, isOpen ? 20 : 20)
    }

    // MARK: - Navigation

    private var navigation: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(DashboardTab.mainTabs) { tab in
                    navItem(tab)
                }
            }
            .padding(.horizontal, isOpen ? 14 : 10)
            .padding(.top, 12)
        }
    }

    // MARK: - Nav Item

    private func navItem(_ tab: DashboardTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)

                if isOpen {
                    Text(tab.label)
                        .font(.epilogue(15, weight: isActive ? .bold : .semiBold))
                        .tracking(-0.04 * 15)

                    Spacer()
                }
            }
            .foregroundStyle(isActive ? ReefColors.black : ReefColors.gray600)
            .padding(.vertical, 8)
            .padding(.horizontal, isOpen ? 14 : 0)
            .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
            .background(
                isActive
                    ? RoundedRectangle(cornerRadius: 10)
                        .fill(ReefColors.accent)
                    : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                isActive
                    ? RoundedRectangle(cornerRadius: 10)
                        .stroke(ReefColors.black, lineWidth: 2)
                    : nil
            )
            .background(
                isActive
                    ? RoundedRectangle(cornerRadius: 10)
                        .fill(ReefColors.black)
                        .offset(x: 3, y: 3)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            // Upgrade
            footerRow {
                circleIcon(fill: ReefColors.accent) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }
            } label: {
                Text("Upgrade")
            } trailing: {
                Text("FREE BETA")
                    .font(.epilogue(10, weight: .black))
                    .tracking(0.02 * 10)
                    .textCase(.uppercase)
                    .foregroundStyle(ReefColors.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ReefColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ReefColors.black, lineWidth: 2)
                    )
            }

            // Settings
            Button {
                selectedTab = .settings
            } label: {
                footerRow {
                    circleIcon(fill: ReefColors.gray100) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ReefColors.black)
                    }
                } label: {
                    Text("Settings")
                } trailing: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(ReefColors.gray400)
                }
            }
            .buttonStyle(.plain)

            // User
            Button {
                selectedTab = .settings
            } label: {
                footerRow {
                    circleIcon(fill: ReefColors.surface) {
                        Text(userInitials)
                            .font(.epilogue(12, weight: .black))
                            .foregroundStyle(ReefColors.black)
                    }
                } label: {
                    Text(displayName)
                        .lineLimit(1)
                } trailing: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(ReefColors.gray400)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isOpen ? 14 : 10)
        .padding(.bottom, 16)
    }

    // MARK: - Footer Helpers

    private func circleIcon<Content: View>(
        fill: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle().stroke(ReefColors.black, lineWidth: 2)
                )
            content()
        }
    }

    private func footerRow<Icon: View, Label: View, Trailing: View>(
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            icon()

            if isOpen {
                label()
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.black)

                Spacer()

                trailing()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isOpen ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)
        .contentShape(Rectangle())
    }

    // MARK: - User Info

    private var displayName: String {
        if let meta = authManager.session?.user.userMetadata["display_name"],
           case .string(let name) = meta {
            return name
        }
        return authManager.session?.user.email?.components(separatedBy: "@").first ?? "User"
    }

    private var userInitials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
