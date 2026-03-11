import SwiftUI

enum ReefButtonVariant {
    case primary
    case secondary
    case destructive
}

struct ReefButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var theme
    let variant: ReefButtonVariant

    private func backgroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: dark ? ReefColors.DashboardDark.card : ReefColors.white
        case .destructive: Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary, .destructive: ReefColors.white
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
        case .destructive: Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ dark: Bool) -> Color {
        switch variant {
        case .primary, .destructive: ReefColors.white
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

/// Adds a 3D neobrutalist push-down animation to any view. Generic over
/// `Shape` so it works with RoundedRectangle, Capsule, Circle, etc.
/// The view should already have its own background and clipShape applied.
struct Reef3DPushModifier<S: Shape>: ViewModifier {
    let shape: S
    let shadowOffset: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowColor: Color
    let action: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .overlay(shape.stroke(borderColor, lineWidth: borderWidth))
            .background(
                shape.fill(shadowColor)
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
    /// 3D push effect with RoundedRectangle shape (most common).
    func reef3DPush(
        cornerRadius: CGFloat = 10,
        shadowOffset: CGFloat = 4,
        borderWidth: CGFloat = 1.5,
        borderColor: Color,
        shadowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        modifier(Reef3DPushModifier(
            shape: RoundedRectangle(cornerRadius: cornerRadius),
            shadowOffset: shadowOffset,
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowColor: shadowColor,
            action: action
        ))
    }

    /// 3D push effect with Capsule shape (pills, tags).
    func reef3DPushCapsule(
        shadowOffset: CGFloat = 3,
        borderWidth: CGFloat = 1.5,
        borderColor: Color,
        shadowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        modifier(Reef3DPushModifier(
            shape: Capsule(),
            shadowOffset: shadowOffset,
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowColor: shadowColor,
            action: action
        ))
    }

    /// 3D push effect with Circle shape (avatars, round buttons).
    func reef3DPushCircle(
        shadowOffset: CGFloat = 2,
        borderWidth: CGFloat = 1.5,
        borderColor: Color,
        shadowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        modifier(Reef3DPushModifier(
            shape: Circle(),
            shadowOffset: shadowOffset,
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowColor: shadowColor,
            action: action
        ))
    }
}

// MARK: - Modal Button

/// Standard button for popups and modal sheets. Handles font, padding, colors,
/// 3D push animation, and disabled state — callers just provide a label and action.
struct ReefModalButton: View {
    @Environment(ThemeManager.self) private var theme

    let label: String
    let variant: ReefButtonVariant
    let isEnabled: Bool
    let action: () -> Void

    init(_ label: String, variant: ReefButtonVariant = .primary, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.variant = variant
        self.isEnabled = isEnabled
        self.action = action
    }

    private func backgroundColor(_ dark: Bool) -> Color {
        guard isEnabled else {
            return dark ? ReefColors.DashboardDark.divider : ReefColors.gray100
        }
        switch variant {
        case .primary: return ReefColors.primary
        case .secondary: return dark ? ReefColors.DashboardDark.divider : ReefColors.gray100
        case .destructive: return Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ dark: Bool) -> Color {
        guard isEnabled else {
            return dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500
        }
        switch variant {
        case .primary, .destructive: return ReefColors.white
        case .secondary: return dark ? ReefColors.DashboardDark.text : ReefColors.black
        }
    }

    var body: some View {
        let dark = theme.isDarkMode
        Text(label)
            .font(.epilogue(14, weight: .bold))
            .tracking(-0.04 * 14)
            .foregroundStyle(foregroundColor(dark))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(backgroundColor(dark))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .reef3DPush(
                cornerRadius: 10,
                borderColor: dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black,
                shadowColor: dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black,
                action: action
            )
            .allowsHitTesting(isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
