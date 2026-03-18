import SwiftUI

// MARK: - Reef Toggle

enum ReefToggleSize {
    case regular
    case compact

    var width: CGFloat {
        switch self {
        case .regular: 52
        case .compact: 38
        }
    }

    var height: CGFloat {
        switch self {
        case .regular: 30
        case .compact: 22
        }
    }

    var thumbSize: CGFloat {
        switch self {
        case .regular: 22
        case .compact: 16
        }
    }

    var padding: CGFloat {
        switch self {
        case .regular: 4
        case .compact: 3
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .regular: 1.5
        case .compact: 1
        }
    }
}

/// Neobrutalist toggle switch used across the app.
struct ReefToggle: View {
    @Environment(ReefTheme.self) private var theme
    @Binding var isOn: Bool
    var size: ReefToggleSize = .regular

    var body: some View {
        let colors = theme.colors
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReefColors.primary : colors.subtle)
                .overlay(Capsule().stroke(colors.border, lineWidth: size.borderWidth))
                .frame(width: size.width, height: size.height)

            Circle()
                .fill(ReefColors.white)
                .frame(width: size.thumbSize, height: size.thumbSize)
                .overlay(Circle().stroke(colors.border, lineWidth: size.borderWidth))
                .padding(size.padding)
                .shadow(color: colors.shadow.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .animation(.spring(duration: 0.2, bounce: 0.3), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .accessibilityAddTraits(.isButton)
    }
}
