import SwiftUI

// MARK: - ReefBadge
//
// A non-interactive pill label with a 3D border offset shadow.
// Variants:
//   .primary   — teal fill, white text (same as ReefButton .primary)
//   .secondary — sand/surface fill, dark text

enum ReefBadgeVariant {
    case primary
    case secondary
}

struct ReefBadge: View {
    @Environment(ReefTheme.self) private var theme

    let text: String
    var variant: ReefBadgeVariant = .primary

    var body: some View {
        let colors = theme.colors
        let bg: Color = variant == .primary ? ReefColors.primary : colors.surface
        let fg: Color = variant == .primary ? ReefColors.white : colors.text

        Text(text.uppercased())
            .font(.epilogue(10, weight: .black))
            .tracking(0.02 * 10)
            .foregroundStyle(fg)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
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
