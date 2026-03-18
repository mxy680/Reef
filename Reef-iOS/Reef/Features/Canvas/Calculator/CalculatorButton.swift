import SwiftUI
import UIKit

// MARK: - Button Style Enum

enum CalcButtonStyle {
    case number
    case operation
    case function
    case action
    case equals
}

// MARK: - CalculatorButton

struct CalculatorButton: View {
    @Environment(ReefTheme.self) private var theme

    let label: String
    var icon: String? = nil
    let style: CalcButtonStyle
    let action: () -> Void

    @State private var isPressed = false

    private let shadowOffset: CGFloat = 2
    private let cornerRadius: CGFloat = 8
    private let borderWidth: CGFloat = 1.5

    // MARK: - Colors

    private var backgroundColor: Color {
        switch style {
        case .number:    return .white
        case .operation: return ReefColors.primary
        case .function:  return ReefColors.gray100
        case .action:    return Color(hex: 0xE57373)
        case .equals:    return ReefColors.primary
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .number:    return .black
        case .operation: return .white
        case .function:  return .black
        case .action:    return .white
        case .equals:    return .white
        }
    }

    private var labelFont: Font {
        switch style {
        case .function: return .system(size: 14)
        default:        return .system(size: 16, weight: .bold)
        }
    }

    // MARK: - Derived press state

    private var currentShadowOffset: CGFloat {
        isPressed ? 0.5 : shadowOffset
    }

    private var pressTranslation: CGFloat {
        isPressed ? shadowOffset - 0.5 : 0
    }

    // MARK: - Body

    var body: some View {
        let colors = theme.colors
        let borderColor = colors.border
        let shadowColor = colors.shadow

        Group {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text(label)
                    .font(labelFont)
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(shadowColor)
                .offset(x: currentShadowOffset, y: currentShadowOffset)
        )
        .offset(x: pressTranslation, y: pressTranslation)
        .animation(.spring(duration: 0.15, bounce: 0.15), value: isPressed)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.12))
                        action()
                    }
                }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .hoverEffectDisabled()
    }
}
