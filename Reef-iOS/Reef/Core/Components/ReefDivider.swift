import SwiftUI

struct ReefDivider: View {
    @Environment(ReefTheme.self) private var theme
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey = "OR") {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(theme.colors.divider)
                .frame(height: 1)

            Text(text)
                .font(.epilogue(12, weight: .semiBold))
                .tracking(0.08 * 12)
                .foregroundStyle(theme.colors.textSecondary)
                .textCase(.uppercase)

            Rectangle()
                .fill(theme.colors.divider)
                .frame(height: 1)
        }
    }
}
