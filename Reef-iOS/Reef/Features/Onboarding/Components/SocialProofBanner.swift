import SwiftUI

struct SocialProofBanner: View {
    @Environment(ReefTheme.self) private var theme

    let text: String

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ReefColors.primary)
                .frame(width: 4)

            Text(text)
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.02 * 13)
                .foregroundStyle(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}
