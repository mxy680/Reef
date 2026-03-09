import SwiftUI

/// Open-bottom triangle shape for the popover arrow stroke.
/// Only draws the two diagonal sides — no bottom edge — so the
/// stroke merges seamlessly with the card's top border.
private struct PopoverArrowStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// Closed triangle for the arrow's white fill (covers the card
/// border beneath the arrow).
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

/// Neobrutalist popover card with an upward-pointing arrow that
/// connects to the trigger button. Wraps any content view.
///
/// Usage:
/// ```
/// PopoverCard(arrowOffset: offsetFromCenter) {
///     MyPopoverContent()
/// }
/// ```
struct PopoverCard<Content: View>: View {
    @Environment(ThemeManager.self) private var theme

    /// Horizontal offset of the arrow tip from the card's center.
    var arrowOffset: CGFloat = 0
    let content: Content

    private let arrowWidth: CGFloat = 16
    private let arrowHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 12
    private let borderWidth: CGFloat = 2
    private let shadowOffset: CGFloat = 4

    init(arrowOffset: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.arrowOffset = arrowOffset
        self.content = content()
    }

    var body: some View {
        let dark = theme.isDarkMode
        let fillColor = dark ? ReefColors.CanvasDark.toolbar : CanvasToolbar.barColor
        let strokeColor = dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black
        let shadowColor = dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black

        VStack(spacing: 0) {
            // Arrow
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
            // Overlap the card top by 1pt so fill hides the border seam
            .offset(y: 1)
            .zIndex(1)

            // Card body
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
                .frame(maxWidth: 190)
        }
    }
}
