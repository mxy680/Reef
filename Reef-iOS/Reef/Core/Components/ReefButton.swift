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

// MARK: - ReefButton (3D variants: primary / secondary / destructive)
//
// Owns the full gesture lifecycle:
//   press → push down → release → spring back → fire action
//
// This is a View, not a ButtonStyle, because ButtonStyle fires
// the action immediately on tap with no way to delay it.

struct ReefButton<Label: View>: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let variant: ReefButtonVariant
    let size: ReefButtonSize
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    /// Time for the spring-back animation to settle before firing action.
    private let springBackDelay: TimeInterval = 0.18

    init(
        _ variant: ReefButtonVariant = .primary,
        size: ReefButtonSize = .regular,
        disabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.isDisabled = disabled
        self.action = action
        self.label = label
    }

    // MARK: - Color Resolution

    private func backgroundColor(_ colors: ReefThemeColors) -> Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: colors.card
        case .destructive: ReefColors.destructive
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

    var body: some View {
        switch variant {
        case .primary, .secondary, .destructive:
            body3D
        case .ghost, .link:
            bodyFlat
        }
    }

    // MARK: - 3D Body

    private var body3D: some View {
        let colors = theme.colors
        let offset = size.shadowOffset
        let radius = size.cornerRadius

        return label()
            .font(.epilogue(size.fontSize, weight: .bold))
            .tracking(-0.04 * size.fontSize)
            .foregroundStyle(foregroundColor(colors))
            .frame(maxWidth: size == .regular ? .infinity : nil)
            .frame(height: size == .regular ? metrics.buttonHeight : nil)
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
                        x: isPressed ? 0 : offset,
                        y: isPressed ? 0 : offset
                    )
            )
            .offset(
                x: isPressed ? offset : 0,
                y: isPressed ? offset : 0
            )
            .compositingGroup()
            .animation(.spring(duration: 0.15, bounce: 0.15), value: isPressed)
            .opacity(isDisabled ? 0.5 : 1)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isDisabled else { return }
                        isPressed = true
                    }
                    .onEnded { _ in
                        guard !isDisabled else { return }
                        isPressed = false
                        // Wait for spring-back animation, then fire
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(springBackDelay))
                            action()
                        }
                    }
            )
            .allowsHitTesting(!isDisabled)
            .accessibilityAddTraits(.isButton)
            .hoverEffectDisabled()
    }

    // MARK: - Flat Body (ghost / link)

    private var bodyFlat: some View {
        let colors = theme.colors

        return label()
            .font(.epilogue(variant == .link ? 14 : size.fontSize, weight: .bold))
            .tracking(-0.04 * (variant == .link ? 14 : size.fontSize))
            .foregroundStyle(foregroundColor(colors))
            .opacity(isPressed ? 0.5 : (isDisabled ? 0.4 : 1))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isDisabled else { return }
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = true }
                    }
                    .onEnded { _ in
                        guard !isDisabled else { return }
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = false }
                        action()
                    }
            )
            .allowsHitTesting(!isDisabled)
            .accessibilityAddTraits(.isButton)
            .hoverEffectDisabled()
    }
}

// MARK: - String Label Convenience

extension ReefButton where Label == Text {
    init(
        _ title: String,
        variant: ReefButtonVariant = .primary,
        size: ReefButtonSize = .regular,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.size = size
        self.isDisabled = disabled
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - 3D Push Modifier (for non-Button views like cards)

struct Reef3DPushModifier<S: Shape>: ViewModifier {
    let shape: S
    let shadowOffset: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowColor: Color
    let action: () -> Void

    @State private var isPressed = false

    private let springBackDelay: TimeInterval = 0.18

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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(springBackDelay))
                            action()
                        }
                    }
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

// MARK: - No Highlight Style (for SwiftUI Button when needed)

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
