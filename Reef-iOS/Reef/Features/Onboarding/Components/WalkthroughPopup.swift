import SwiftUI

/// Neobrutalist popup card for walkthrough steps.
struct WalkthroughPopup: View {
    @Environment(ReefTheme.self) private var theme

    let step: WalkthroughStep
    let onGotIt: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let colors = theme.colors
        let position = step.position

        ZStack {
            // Dim background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(!step.requiresAction)
                .onTapGesture {
                    if !step.requiresAction {
                        onGotIt()
                    }
                }

            // Card + skip button stack
            VStack(spacing: 14) {
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
                    }
                }
                .padding(20)
                .frame(maxWidth: 360, alignment: .leading)
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

                // Skip button — primary style below card
                ReefButton(.secondary, size: .compact, action: onSkip) {
                    Text("Skip tutorial")
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
            .padding(position.padding)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Position Helpers

extension WalkthroughPopupPosition {
    var alignment: Alignment {
        switch self {
        case .bottomLeading: .bottomLeading
        case .topCenter: .top
        case .topTrailing: .topTrailing
        case .center: .center
        case .centerTrailing: .trailing
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .bottomLeading: EdgeInsets(top: 0, leading: 20, bottom: 80, trailing: 0)
        case .topCenter: EdgeInsets(top: 100, leading: 20, bottom: 0, trailing: 20)
        case .topTrailing: EdgeInsets(top: 100, leading: 0, bottom: 0, trailing: 20)
        case .center: EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 40)
        case .centerTrailing: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20)
        }
    }
}
