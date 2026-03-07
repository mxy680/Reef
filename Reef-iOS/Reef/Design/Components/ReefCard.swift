import SwiftUI

struct ReefCard<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let dark = theme.isDarkMode
        content
            .padding(.horizontal, 36)
            .padding(.vertical, 40)
            .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black)
                    .offset(x: 6, y: 6)
            )
    }
}
