import SwiftUI

// MARK: - ReefBadge
//
// A non-interactive label styled like a primary ReefButton:
// teal fill, white text, black 3D border offset shadow.

struct ReefBadge: View {
    @Environment(ReefTheme.self) private var theme

    let text: String

    var body: some View {
        let colors = theme.colors
        Text(text.uppercased())
            .font(.epilogue(10, weight: .black))
            .tracking(0.02 * 10)
            .foregroundStyle(ReefColors.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ReefColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colors.border, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors.shadow)
                    .offset(x: 3, y: 3)
            )
            .compositingGroup()
    }
}
