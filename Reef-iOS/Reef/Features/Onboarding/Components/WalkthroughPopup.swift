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
            // Dim background (light, not fully blocking)
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(!step.requiresAction) // Pass through if waiting for action
                .onTapGesture {
                    if !step.requiresAction {
                        onGotIt()
                    }
                }

            // Popup card — positioned based on step
            VStack(alignment: .leading, spacing: 12) {
                Text(step.text)
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    if !step.requiresAction {
                        ReefButton(step.buttonLabel, size: .compact, action: onGotIt)
                    }

                    Button(action: onSkip) {
                        Text("Skip tutorial")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(colors.textMuted)
                    }
                    .buttonStyle(NoHighlightButtonStyle())
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
