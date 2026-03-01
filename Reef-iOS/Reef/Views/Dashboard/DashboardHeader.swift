import SwiftUI

struct DashboardHeader: View {
    let selectedTab: DashboardTab
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        HStack {
            // Breadcrumbs
            HStack(spacing: 8) {
                Text("Dashboard")
                    .font(.epilogue(16, weight: .semiBold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(ReefColors.gray600)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ReefColors.gray400)

                Text(selectedTab.label)
                    .font(.epilogue(16, weight: .black))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(ReefColors.black)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                headerButton("magnifyingglass")
                headerButton("questionmark.circle")

                // Bell with notification dot
                ZStack(alignment: .topTrailing) {
                    headerButton("bell")
                    Circle()
                        .fill(Color(hex: 0xE74C3C))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(ReefColors.white, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }

                // Streak pill
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ReefColors.black)
                    Text("0")
                        .font(.epilogue(13, weight: .semiBold))
                        .foregroundStyle(ReefColors.black)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ReefColors.surface)
                .clipShape(Capsule())

                // Profile circle
                ZStack {
                    Circle()
                        .fill(ReefColors.accent)
                        .frame(width: 32, height: 32)
                    Text(userInitials)
                        .font(.epilogue(12, weight: .bold))
                        .foregroundStyle(ReefColors.black)
                }
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 24)
        .dashboardCard()
    }

    private func headerButton(_ icon: String) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(ReefColors.gray600)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private var userInitials: String {
        let email = authManager.session?.user.email ?? "U"
        let name = email.components(separatedBy: "@").first ?? "U"
        return String(name.prefix(2)).uppercased()
    }
}
