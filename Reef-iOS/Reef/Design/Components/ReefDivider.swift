import SwiftUI

struct ReefDivider: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(ReefColors.primary)
                .frame(height: 1)

            Text("OR")
                .font(.epilogue(12, weight: .semiBold))
                .tracking(0.08 * 12)
                .foregroundStyle(theme.isDarkMode ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .textCase(.uppercase)

            Rectangle()
                .fill(ReefColors.primary)
                .frame(height: 1)
        }
    }
}
