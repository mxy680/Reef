import SwiftUI

/// Standard popup/modal shell with dark mode support.
/// Replaces the repeated inline pattern of white bg + black border/shadow.
struct PopupShellModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    var cornerRadius: CGFloat = 16
    var maxWidth: CGFloat = 400
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        let dark = theme.isDarkMode
        content
            .background(dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black)
                    .offset(x: shadowOffset, y: shadowOffset)
            )
            .frame(maxWidth: maxWidth)
    }
}

extension View {
    func popupShell(cornerRadius: CGFloat = 16, maxWidth: CGFloat = 400, shadowOffset: CGFloat = 4) -> some View {
        modifier(PopupShellModifier(cornerRadius: cornerRadius, maxWidth: maxWidth, shadowOffset: shadowOffset))
    }
}
