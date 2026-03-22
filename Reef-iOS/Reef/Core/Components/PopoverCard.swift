import SwiftUI

/// Open-bottom triangle shape for the popover arrow stroke.
private struct PopoverArrowStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// Closed triangle for the arrow's fill.
private struct PopoverArrowFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Neobrutalist popover card with an upward-pointing arrow.
struct PopoverCard<Content: View>: View {
    @Environment(ReefTheme.self) private var theme

    var arrowOffset: CGFloat = 0
    var maxWidth: CGFloat = 190
    let content: Content

    private let arrowWidth: CGFloat = 16
    private let arrowHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 12
    private let borderWidth: CGFloat = 2
    private let shadowOffset: CGFloat = 4

    init(arrowOffset: CGFloat = 0, maxWidth: CGFloat = 190, @ViewBuilder content: () -> Content) {
        self.arrowOffset = arrowOffset
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        let dark = theme.isDarkMode
        let fillColor = dark ? ReefColors.Dark.cardElevated : ReefColors.white
        let strokeColor = dark ? ReefColors.Dark.popupBorder : ReefColors.black
        let shadowColor = dark ? ReefColors.Dark.popupShadow : ReefColors.black

        VStack(spacing: 0) {
            ZStack {
                PopoverArrowFill()
                    .fill(fillColor)
                    .frame(width: arrowWidth, height: arrowHeight)

                PopoverArrowStroke()
                    .stroke(strokeColor, lineWidth: borderWidth)
                    .frame(width: arrowWidth, height: arrowHeight)
            }
            .frame(width: arrowWidth, height: arrowHeight)
            .offset(x: arrowOffset)
            .offset(y: 1)
            .zIndex(1)

            content
                .background(fillColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(strokeColor, lineWidth: borderWidth)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(shadowColor)
                        .offset(x: shadowOffset, y: shadowOffset)
                )
                .frame(maxWidth: maxWidth)
        }
    }
}
