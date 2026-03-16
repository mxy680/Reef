import SwiftUI

struct ReefDivider: View {
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(ReefColors.primary)
                .frame(height: 1)

            Text("OR")
                .font(.epilogue(12, weight: .semiBold))
                .tracking(0.08 * 12)
                .foregroundStyle(theme.colors.textSecondary)
                .textCase(.uppercase)

            Rectangle()
                .fill(ReefColors.primary)
                .frame(height: 1)
        }
    }
}
