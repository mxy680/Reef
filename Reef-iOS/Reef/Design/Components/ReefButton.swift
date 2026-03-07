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
