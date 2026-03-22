import SwiftUI

/// Card style for dashboard panels (sidebar, header, content).
/// Uses gray500 borders and a subtle 3pt offset shadow,
/// distinct from the auth-screen ReefCard (black border, 6pt shadow).
struct DashboardCardModifier: ViewModifier {
    @Environment(ReefTheme.self) private var theme

    func body(content: Content) -> some View {
        let colors = theme.colors
        content
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.isDarkMode ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.isDarkMode ? ReefColors.Dark.shadow : ReefColors.gray500)
                    .offset(x: 3, y: 3)
            )
            .compositingGroup()
    }
}

extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}
