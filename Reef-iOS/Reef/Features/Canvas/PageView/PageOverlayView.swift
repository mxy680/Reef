import UIKit

// MARK: - Page Overlay View (grid / dots / lines)

final class CanvasPageOverlayView: UIView {
    var overlayType: CanvasOverlayType = .none
    var spacing: CGFloat = 20
    var overlayOpacity: CGFloat = 0.35

    private var overlayColor: UIColor {
        UIColor(white: 0.72, alpha: overlayOpacity)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard overlayType != .none else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setStrokeColor(overlayColor.cgColor)
        ctx.setFillColor(overlayColor.cgColor)

        // Scale spacing by the 2x render factor
        let scaledSpacing = spacing * 2.0

        switch overlayType {
        case .none:
            break

        case .grid:
            ctx.setLineWidth(0.5)
            var x: CGFloat = scaledSpacing
            while x < rect.width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: rect.height))
                x += scaledSpacing
            }
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += scaledSpacing
            }
            ctx.strokePath()

        case .dots:
            let dotSize: CGFloat = 2.0
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                var x: CGFloat = scaledSpacing
                while x < rect.width {
                    let dotRect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    ctx.fillEllipse(in: dotRect)
                    x += scaledSpacing
                }
                y += scaledSpacing
            }

        case .lines:
            ctx.setLineWidth(0.5)
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += scaledSpacing
            }
            ctx.strokePath()
        }
    }
}
