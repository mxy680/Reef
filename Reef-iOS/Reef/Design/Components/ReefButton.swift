import SwiftUI

enum ReefButtonVariant {
    case primary
    case secondary
}

struct ReefButtonStyle: ButtonStyle {
    let variant: ReefButtonVariant

    private var backgroundColor: Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: ReefColors.white
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: ReefColors.white
        case .secondary: ReefColors.black
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .reefButton()
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReefColors.black, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.black)
                    .offset(
                        x: pressed ? 0 : 4,
                        y: pressed ? 0 : 4
                    )
            )
            .offset(
                x: pressed ? 4 : 0,
                y: pressed ? 4 : 0
            )
            .animation(.spring(duration: 0.4, bounce: 0.2), value: pressed)
    }
}

struct ReefCompactButtonStyle: ButtonStyle {
    let variant: ReefButtonVariant

    private var backgroundColor: Color {
        switch variant {
        case .primary: ReefColors.primary
        case .secondary: ReefColors.white
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: ReefColors.white
        case .secondary: ReefColors.black
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ReefColors.black, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ReefColors.black)
                    .offset(
                        x: pressed ? 0 : 3,
                        y: pressed ? 0 : 3
                    )
            )
            .offset(
                x: pressed ? 3 : 0,
                y: pressed ? 3 : 0
            )
            .animation(.spring(duration: 0.2, bounce: 0.1), value: pressed)
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
