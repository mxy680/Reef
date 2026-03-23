import SwiftUI

/// Neobrutalist popup card for walkthrough steps.
struct WalkthroughPopup: View {
    @Environment(ReefTheme.self) private var theme

    let step: WalkthroughStep
    let onGotIt: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let colors = theme.colors

        // Bottom-left aligned — card + skip button
        VStack(alignment: .leading, spacing: 10) {
            // Popup card
            VStack(alignment: .leading, spacing: 14) {
                Text(step.text)
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                if !step.requiresAction {
                    ReefButton(step.buttonLabel, size: .compact, action: onGotIt)
                        .frame(maxWidth: 160)
                }
            }
            .padding(20)
            .frame(maxWidth: 340, alignment: .leading)
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colors.shadow)
                    .offset(x: 4, y: 4)
            )

            // Skip button — teal primary
            ReefButton("Skip tutorial", size: .compact, action: onSkip)
                .frame(maxWidth: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 20)
        .padding(.bottom, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .allowsHitTesting(true)
    }
}

