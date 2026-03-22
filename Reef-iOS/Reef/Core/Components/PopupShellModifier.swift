import SwiftUI

struct PopupShellModifier: ViewModifier {
    @Environment(ReefTheme.self) private var theme
    var cornerRadius: CGFloat = 16
    var maxWidth: CGFloat = 400
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        let colors = theme.colors
        content
            .background(colors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colors.shadow)
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
