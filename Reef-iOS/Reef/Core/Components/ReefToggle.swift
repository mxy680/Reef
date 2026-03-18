import SwiftUI

// MARK: - Reef Toggle

/// Neobrutalist toggle switch used across the app.
/// Replaces the old `SettingsToggle` with a reusable component.
struct ReefToggle: View {
    @Environment(ReefTheme.self) private var theme
    @Binding var isOn: Bool

    private let width: CGFloat = 52
    private let height: CGFloat = 30
    private let thumbSize: CGFloat = 22

    var body: some View {
        let colors = theme.colors
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReefColors.primary : colors.subtle)
                .overlay(Capsule().stroke(colors.border, lineWidth: 1.5))
                .frame(width: width, height: height)

            Circle()
                .fill(ReefColors.white)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(Circle().stroke(colors.border, lineWidth: 1))
                .padding(4)
                .shadow(color: colors.shadow.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .animation(.spring(duration: 0.2, bounce: 0.3), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .accessibilityAddTraits(.isButton)
    }
}
