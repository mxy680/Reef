import SwiftUI

enum ReefButtonVariant {
    case primary
    case secondary
}

struct ReefButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var theme
    let variant: ReefButtonVariant

    private func backgroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: dark ? ReefColors.DashboardDark.card : ReefColors.white
        }
    }

    private func foregroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary: ReefColors.white
        case .secondary: dark ? ReefColors.DashboardDark.text : ReefColors.black
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let dark = theme.isDarkMode
        let borderColor = dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black
        let shadowColor = dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black
        configuration.label
            .reefButton()
            .foregroundStyle(foregroundColor(dark))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor(dark))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(shadowColor)
                    .offset(
                        x: pressed ? 0 : 4,
                        y: pressed ? 0 : 4
                    )
            )
            .offset(
                x: pressed ? 4 : 0,
                y: pressed ? 4 : 0
            )
            .compositingGroup()
            .animation(.spring(duration: 0.4, bounce: 0.2), value: pressed)
            .hoverEffectDisabled()
    }
}

struct ReefCompactButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var theme
    let variant: ReefButtonVariant

    private func backgroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: dark ? ReefColors.DashboardDark.card : ReefColors.white
        }
    }

    private func foregroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary: ReefColors.white
        case .secondary: dark ? ReefColors.DashboardDark.text : ReefColors.black
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let dark = theme.isDarkMode
        let borderColor = dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black
        let shadowColor = dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black
        configuration.label
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(foregroundColor(dark))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor(dark))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(shadowColor)
                    .offset(
                        x: pressed ? 0 : 3,
                        y: pressed ? 0 : 3
                    )
            )
            .offset(
                x: pressed ? 3 : 0,
                y: pressed ? 3 : 0
            )
            .compositingGroup()
            .animation(.spring(duration: 0.2, bounce: 0.1), value: pressed)
            .hoverEffectDisabled()
    }
}

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension Button {
    func reefStyle(_ variant: ReefButtonVariant = .primary) -> some View {
        self.buttonStyle(ReefButtonStyle(variant: variant))
    }

    func reefCompactStyle(_ variant: ReefButtonVariant = .primary) -> some View {
        self.buttonStyle(ReefCompactButtonStyle(variant: variant))
    }
}

// MARK: - 3D Push Modifier

/// Adds the 3D push-down animation to any view that already has a neobrutalist
/// shadow/border setup. Replaces the static shadow + onTapGesture pattern with
/// an animated press effect.
///
/// The view content should already include its own background, clipShape, and
/// overlay stroke. This modifier wraps it with:
/// - A shadow layer that retracts on press
/// - An offset that pushes the view into the shadow on press
/// - A DragGesture to track press state
/// - An onTapGesture for the action
struct Reef3DPushModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOffset: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowColor: Color
    let action: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadowColor)
                    .offset(
                        x: isPressed ? 0 : shadowOffset,
                        y: isPressed ? 0 : shadowOffset
                    )
            )
            .offset(
                x: isPressed ? shadowOffset : 0,
                y: isPressed ? shadowOffset : 0
            )
            .compositingGroup()
            .animation(.spring(duration: 0.2, bounce: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    /// Adds a 3D neobrutalist push effect. Apply this to a view that already
    /// has its own background and clipShape — this adds the border, shadow,
    /// press animation, and tap action.
    func reef3DPush(
        cornerRadius: CGFloat = 10,
        shadowOffset: CGFloat = 4,
        borderWidth: CGFloat = 1.5,
        borderColor: Color,
        shadowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        modifier(Reef3DPushModifier(
            cornerRadius: cornerRadius,
            shadowOffset: shadowOffset,
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowColor: shadowColor,
            action: action
        ))
    }
}
