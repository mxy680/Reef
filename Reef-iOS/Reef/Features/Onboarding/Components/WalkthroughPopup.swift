import SwiftUI

/// Neobrutalist card for a single walkthrough step.
/// Positioning and stacking is handled by the parent view.
struct WalkthroughCard: View {
    @Environment(ReefTheme.self) private var theme

    let step: WalkthroughStep
    let showButtons: Bool
    var onGotIt: (() -> Void)? = nil

    var body: some View {
        let colors = theme.colors

        VStack(alignment: .leading, spacing: 12) {
            Text(step.text)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            if showButtons, !step.requiresAction, let onGotIt {
                ReefButton(step.buttonLabel, size: .compact, action: onGotIt)
                    .frame(maxWidth: 140)
            }
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colors.border, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colors.shadow)
                .offset(x: 3, y: 3)
        )
    }
}
