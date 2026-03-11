import SwiftUI

// MARK: - Dotted Background

struct DottedBackground: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        let dotColor = dark ? ReefColors.DashboardDark.subtle : ReefColors.gray200
        let bgColor = dark ? ReefColors.DashboardDark.background : ReefColors.white

        Canvas { context, size in
            let spacing: CGFloat = 20
            let dotSize: CGFloat = 1.5

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(dotColor)
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .background(bgColor)
    }
}
