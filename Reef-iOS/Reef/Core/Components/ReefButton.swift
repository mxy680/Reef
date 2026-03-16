import SwiftUI

// MARK: - Button Size

enum ReefButtonSize: Equatable {
    case regular    // 48pt height, full-width
    case compact    // Intrinsic height, horizontal padding

    var cornerRadius: CGFloat {
        switch self {
        case .regular: 12
        case .compact: 8
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .regular: 2
        case .compact: 1.5
        }
    }

    var shadowOffset: CGFloat {
        switch self {
        case .regular: 4
        case .compact: 3
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .regular: 16
        case .compact: 12
        }
    }
}

// MARK: - Button Variant

enum ReefButtonVariant {
    /// Teal filled — primary CTA
    case primary
    /// White/card filled — secondary actions
    case secondary
    /// Red filled — destructive actions
    case destructive
    /// No background, no border — text-only action
    case ghost
    /// Inline colored text — navigation links, inline actions
    case link
}

// MARK: - 3D Neobrutalist Button Style

struct ReefButtonStyle: ButtonStyle {
    @Environment(ReefTheme.self) private var theme
    let variant: ReefButtonVariant
    let size: ReefButtonSize

    // MARK: - Color Resolution

    private func backgroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: colors.card
        case .destructive: Color(hex: 0xC62828)
        case .ghost, .link: .clear
        }
    }

    private func foregroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary, .destructive: ReefColors.white
        case .secondary: colors.text
        case .ghost: colors.text
        case .link: ReefColors.primary
        }
    }

    // MARK: - Body

    func makeBody(configuration: Configuration) -> some View {
        switch variant {
        case .primary, .secondary, .destructive:
            make3DBody(configuration: configuration)
        case .ghost, .link:
            makeFlatBody(configuration: configuration)
        }
    }

    // MARK: - 3D Variant (primary / secondary / destructive)

    @ViewBuilder
    private func make3DBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let colors = theme.colors
        let offset = size.shadowOffset
        let radius = size.cornerRadius

        configuration.label
            .font(.epilogue(size.fontSize, weight: .bold))
            .tracking(-0.04 * size.fontSize)
            .foregroundStyle(foregroundColor(colors))
            .frame(maxWidth: size == .regular ? .infinity : nil)
            .frame(height: size == .regular ? 48 : nil)
            .padding(.horizontal, size == .compact ? 14 : 0)
            .padding(.vertical, size == .compact ? 8 : 0)
            .background(backgroundColor(colors))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(colors.border, lineWidth: size.borderWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(colors.shadow)
                    .offset(
                        x: pressed ? 0 : offset,
                        y: pressed ? 0 : offset
                    )
            )
            .offset(
                x: pressed ? offset : 0,
                y: pressed ? offset : 0
            )
            .compositingGroup()
            .animation(.spring(duration: 0.15, bounce: 0.15), value: pressed)
            .hoverEffectDisabled()
    }

    // MARK: - Flat Variant (ghost / link)

    @ViewBuilder
    private func makeFlatBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let colors = theme.colors

        configuration.label
            .font(.epilogue(variant == .link ? 14 : size.fontSize, weight: .bold))
            .tracking(-0.04 * (variant == .link ? 14 : size.fontSize))
            .foregroundStyle(foregroundColor(colors))
            .opacity(pressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
            .hoverEffectDisabled()
    }
}

// MARK: - Button Convenience API

extension Button {
    func reefStyle(
        _ variant: ReefButtonVariant = .primary,
        size: ReefButtonSize = .regular
    ) -> some View {
        self.buttonStyle(ReefButtonStyle(variant: variant, size: size))
    }
}

// MARK: - 3D Push Modifier (for non-Button views)

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
            .animation(.spring(duration: 0.15, bounce: 0.15), value: isPressed)
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

// MARK: - No Highlight Style

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
