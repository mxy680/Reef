import SwiftUI

struct DottedBackground: View {
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let dotColor = theme.isDarkMode ? ReefColors.Dark.subtle : ReefColors.gray200
        let bgColor = theme.isDarkMode ? ReefColors.Dark.background : ReefColors.white

        Canvas { context, size in
            let spacing: CGFloat = 20
            let dotSize: CGFloat = 1.5

            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    path.addEllipse(in: CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    ))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(dotColor))
        }
        .background(bgColor)
    }
}
