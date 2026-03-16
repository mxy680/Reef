import SwiftUI

// MARK: - Button Size

enum ReefButtonSize {
    case regular    // 48pt height, full-width
    case compact    // Intrinsic height, horizontal padding

    var height: CGFloat? {
        switch self {
        case .regular: 48
        case .compact: nil
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: 0
        case .compact: 14
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular: 0
        case .compact: 8
        }
    }

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
    /// Teal filled button — primary CTA
    case primary
    /// White/card filled button — secondary actions
    case secondary
    /// Red filled button — destructive actions
    case destructive
    /// No background, no border — text-only action
    case ghost
    /// Inline colored text — navigation links
    case link
}

// MARK: - 3D Neobrutalist Button Style

/// Single unified button style that handles all variants and sizes.
/// Primary/secondary/destructive get the 3D push-down effect.
/// Ghost and link get a simple opacity feedback.
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

    private var has3DEffect: Bool {
        switch variant {
        case .primary, .secondary, .destructive: true
        case .ghost, .link: false
        }
    }

    // MARK: - Body

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let colors = theme.colors
        let offset = size.shadowOffset
        let radius = size.cornerRadius

        configuration.label
            .font(.epilogue(size.fontSize, weight: .bold))
            .tracking(-0.04 * size.fontSize)
            .foregroundStyle(foregroundColor(colors))
            // Sizing
            .then { view in
                if size == .regular {
                    view
                        .frame(maxWidth: .infinity)
                        .frame(height: size.height ?? 48)
                } else {
                    view
                        .padding(.horizontal, size.horizontalPadding)
                        .padding(.vertical, size.verticalPadding)
                }
            }
            .background(backgroundColor(colors))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            // 3D effect (primary/secondary/destructive only)
            .then { view in
                if has3DEffect {
                    view
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
                } else {
                    view
                        .opacity(pressed ? 0.6 : 1)
                        .animation(.easeOut(duration: 0.1), value: pressed)
                }
            }
            .hoverEffectDisabled()
    }
}

// MARK: - View.then() helper

/// Allows inline conditional view transformations without type-erasure.
extension View {
    @ViewBuilder
    func then<V: View>(@ViewBuilder _ transform: (Self) -> V) -> some View {
        transform(self)
    }
}

// MARK: - Button Convenience API

extension Button {
    /// Apply Reef neobrutalist button styling.
    ///
    ///     Button("Continue") { ... }
    ///         .reefStyle(.primary)
    ///
    ///     Button("Google") { ... }
    ///         .reefStyle(.secondary)
    ///
    ///     Button("Delete") { ... }
    ///         .reefStyle(.destructive, size: .compact)
    ///
    ///     Button("Skip") { ... }
    ///         .reefStyle(.ghost)
    ///
    ///     Button("Sign up") { ... }
    ///         .reefStyle(.link)
    ///
    func reefStyle(
        _ variant: ReefButtonVariant = .primary,
        size: ReefButtonSize = .regular
    ) -> some View {
        self.buttonStyle(ReefButtonStyle(variant: variant, size: size))
    }
}

// MARK: - 3D Push Modifier (for non-Button views)

/// Adds a 3D neobrutalist push-down animation to any view.
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
