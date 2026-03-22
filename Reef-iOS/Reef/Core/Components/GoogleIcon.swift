import SwiftUI

struct GoogleIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48

            // Red (#EA4335)
            var redPath = Path()
            redPath.move(to: CGPoint(x: 24 * scale, y: 9.5 * scale))
            redPath.addCurve(
                to: CGPoint(x: 33.21 * scale, y: 13.1 * scale),
                control1: CGPoint(x: 27.54 * scale, y: 9.5 * scale),
                control2: CGPoint(x: 30.71 * scale, y: 10.72 * scale)
            )
            redPath.addLine(to: CGPoint(x: 40.06 * scale, y: 6.25 * scale))
            redPath.addCurve(
                to: CGPoint(x: 24 * scale, y: 0),
                control1: CGPoint(x: 35.9 * scale, y: 2.38 * scale),
                control2: CGPoint(x: 30.47 * scale, y: 0)
            )
            redPath.addCurve(
                to: CGPoint(x: 2.56 * scale, y: 13.22 * scale),
                control1: CGPoint(x: 14.62 * scale, y: 0),
                control2: CGPoint(x: 6.51 * scale, y: 5.38 * scale)
            )
            redPath.addLine(to: CGPoint(x: 10.54 * scale, y: 19.41 * scale))
            redPath.addCurve(
                to: CGPoint(x: 24 * scale, y: 9.5 * scale),
                control1: CGPoint(x: 12.43 * scale, y: 13.72 * scale),
                control2: CGPoint(x: 17.74 * scale, y: 9.5 * scale)
            )
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(hex: 0xEA4335)))

            // Blue (#4285F4)
            var bluePath = Path()
            bluePath.move(to: CGPoint(x: 46.98 * scale, y: 24.55 * scale))
            bluePath.addCurve(
                to: CGPoint(x: 46.6 * scale, y: 20 * scale),
                control1: CGPoint(x: 46.98 * scale, y: 22.98 * scale),
                control2: CGPoint(x: 46.83 * scale, y: 21.46 * scale)
            )
            bluePath.addLine(to: CGPoint(x: 24 * scale, y: 20 * scale))
            bluePath.addLine(to: CGPoint(x: 24 * scale, y: 29.02 * scale))
            bluePath.addLine(to: CGPoint(x: 36.94 * scale, y: 29.02 * scale))
            bluePath.addCurve(
                to: CGPoint(x: 32.16 * scale, y: 36.2 * scale),
                control1: CGPoint(x: 36.36 * scale, y: 31.98 * scale),
                control2: CGPoint(x: 34.68 * scale, y: 34.5 * scale)
            )
            bluePath.addLine(to: CGPoint(x: 39.89 * scale, y: 42.2 * scale))
            bluePath.addCurve(
                to: CGPoint(x: 46.98 * scale, y: 24.55 * scale),
                control1: CGPoint(x: 44.4 * scale, y: 38.02 * scale),
                control2: CGPoint(x: 46.98 * scale, y: 31.84 * scale)
            )
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(hex: 0x4285F4)))

            // Yellow (#FBBC05)
            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
            yellowPath.addCurve(
                to: CGPoint(x: 9.77 * scale, y: 24 * scale),
                control1: CGPoint(x: 10.05 * scale, y: 27.14 * scale),
                control2: CGPoint(x: 9.77 * scale, y: 25.6 * scale)
            )
            yellowPath.addCurve(
                to: CGPoint(x: 10.53 * scale, y: 19.41 * scale),
                control1: CGPoint(x: 9.77 * scale, y: 22.4 * scale),
                control2: CGPoint(x: 10.04 * scale, y: 20.86 * scale)
            )
            yellowPath.addLine(to: CGPoint(x: 2.55 * scale, y: 13.22 * scale))
            yellowPath.addCurve(
                to: CGPoint(x: 0, y: 24 * scale),
                control1: CGPoint(x: 0.92 * scale, y: 16.46 * scale),
                control2: CGPoint(x: 0, y: 20.12 * scale)
            )
            yellowPath.addCurve(
                to: CGPoint(x: 2.56 * scale, y: 34.78 * scale),
                control1: CGPoint(x: 0, y: 27.88 * scale),
                control2: CGPoint(x: 0.92 * scale, y: 31.54 * scale)
            )
            yellowPath.addLine(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(hex: 0xFBBC05)))

            // Green (#34A853)
            var greenPath = Path()
            greenPath.move(to: CGPoint(x: 24 * scale, y: 48 * scale))
            greenPath.addCurve(
                to: CGPoint(x: 39.89 * scale, y: 42.19 * scale),
                control1: CGPoint(x: 30.48 * scale, y: 48 * scale),
                control2: CGPoint(x: 35.93 * scale, y: 45.87 * scale)
            )
            greenPath.addLine(to: CGPoint(x: 32.16 * scale, y: 36.19 * scale))
            greenPath.addCurve(
                to: CGPoint(x: 24 * scale, y: 38.49 * scale),
                control1: CGPoint(x: 30.01 * scale, y: 37.64 * scale),
                control2: CGPoint(x: 27.24 * scale, y: 38.49 * scale)
            )
            greenPath.addCurve(
                to: CGPoint(x: 10.53 * scale, y: 28.58 * scale),
                control1: CGPoint(x: 17.74 * scale, y: 38.49 * scale),
                control2: CGPoint(x: 12.43 * scale, y: 34.27 * scale)
            )
            greenPath.addLine(to: CGPoint(x: 2.55 * scale, y: 34.77 * scale))
            greenPath.addCurve(
                to: CGPoint(x: 24 * scale, y: 48 * scale),
                control1: CGPoint(x: 6.51 * scale, y: 42.62 * scale),
                control2: CGPoint(x: 14.62 * scale, y: 48 * scale)
            )
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(hex: 0x34A853)))
        }
        .frame(width: 20, height: 20)
    }
}
