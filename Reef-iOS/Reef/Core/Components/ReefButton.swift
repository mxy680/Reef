import SwiftUI

// MARK: - Button Variant

enum ReefButtonVariant {
    case primary
    case secondary
    case destructive
}

// MARK: - Full-Width Button Style

struct ReefButtonStyle: ButtonStyle {
    @Environment(ReefTheme.self) private var theme
    let variant: ReefButtonVariant

    private func backgroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: colors.card
        case .destructive: Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary, .destructive: ReefColors.white
        case .secondary: colors.text
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let colors = theme.colors
        configuration.label
            .reefButton()
            .foregroundStyle(foregroundColor(colors))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor(colors))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colors.shadow)
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

// MARK: - Compact Button Style

struct ReefCompactButtonStyle: ButtonStyle {
    @Environment(ReefTheme.self) private var theme
    let variant: ReefButtonVariant

    private func backgroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: colors.card
        case .destructive: Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary, .destructive: ReefColors.white
        case .secondary: colors.text
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let colors = theme.colors
        configuration.label
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(foregroundColor(colors))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor(colors))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colors.border, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colors.shadow)
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

// MARK: - No Highlight Style

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - Button Convenience

extension Button {
    func reefStyle(_ variant: ReefButtonVariant = .primary) -> some View {
        self.buttonStyle(ReefButtonStyle(variant: variant))
    }

    func reefCompactStyle(_ variant: ReefButtonVariant = .primary) -> some View {
        self.buttonStyle(ReefCompactButtonStyle(variant: variant))
    }
}

// MARK: - 3D Push Modifier

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

struct ReefModalButton: View {
    @Environment(ReefTheme.self) private var theme

    let label: String
    let variant: ReefButtonVariant
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ label: String,
        variant: ReefButtonVariant = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.variant = variant
        self.isEnabled = isEnabled
        self.action = action
    }

    private func backgroundColor(_ colors: ReefThemeColors) -> Color {
        guard isEnabled else {
            return theme.isDarkMode ? ReefColors.Dark.divider : ReefColors.gray100
        }
        switch variant {
        case .primary: return ReefColors.primary
        case .secondary: return theme.isDarkMode ? ReefColors.Dark.divider : ReefColors.gray100
        case .destructive: return Color(hex: 0xC62828)
        }
    }

    private func foregroundColor(_ colors: ReefThemeColors) -> Color {
        guard isEnabled else {
            return theme.isDarkMode ? ReefColors.Dark.textMuted : ReefColors.gray500
        }
        switch variant {
        case .primary, .destructive: return ReefColors.white
        case .secondary: return colors.text
        }
    }

    var body: some View {
        let colors = theme.colors
        Text(label)
            .font(.epilogue(14, weight: .bold))
            .tracking(-0.04 * 14)
            .foregroundStyle(foregroundColor(colors))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(backgroundColor(colors))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .reef3DPush(
                cornerRadius: 10,
                borderColor: colors.border,
                shadowColor: colors.shadow,
                action: action
            )
            .allowsHitTesting(isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
