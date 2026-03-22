import SwiftUI

struct ReefCard<Content: View>: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let colors = theme.colors
        content
            .padding(.horizontal, metrics.reefCardHPadding)
            .padding(.vertical, metrics.reefCardVPadding)
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colors.shadow)
                    .offset(x: 6, y: 6)
            )
    }
}
