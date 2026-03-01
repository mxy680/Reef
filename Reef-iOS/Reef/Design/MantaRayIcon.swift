import SwiftUI

struct MantaRayShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // Start at center top (gap between cephalic fins)
        path.move(to: CGPoint(x: 0.5 * w, y: 0.18 * h))

        // Left cephalic fin
        path.addCurve(
            to: CGPoint(x: 0.36 * w, y: 0.0 * h),
            control1: CGPoint(x: 0.46 * w, y: 0.08 * h),
            control2: CGPoint(x: 0.40 * w, y: 0.0 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.30 * w, y: 0.18 * h),
            control1: CGPoint(x: 0.32 * w, y: 0.0 * h),
            control2: CGPoint(x: 0.30 * w, y: 0.10 * h)
        )

        // Left wing — sweeps out wide
        path.addCurve(
            to: CGPoint(x: 0.0 * w, y: 0.36 * h),
            control1: CGPoint(x: 0.14 * w, y: 0.18 * h),
            control2: CGPoint(x: 0.0 * w, y: 0.22 * h)
        )

        // Left wing trailing edge — curves back in
        path.addCurve(
            to: CGPoint(x: 0.34 * w, y: 0.54 * h),
            control1: CGPoint(x: 0.02 * w, y: 0.50 * h),
            control2: CGPoint(x: 0.18 * w, y: 0.54 * h)
        )

        // Body taper to tail
        path.addCurve(
            to: CGPoint(x: 0.5 * w, y: 1.0 * h),
            control1: CGPoint(x: 0.44 * w, y: 0.58 * h),
            control2: CGPoint(x: 0.48 * w, y: 0.82 * h)
        )

        // Right side — mirror from tail back up
        path.addCurve(
            to: CGPoint(x: 0.66 * w, y: 0.54 * h),
            control1: CGPoint(x: 0.52 * w, y: 0.82 * h),
            control2: CGPoint(x: 0.56 * w, y: 0.58 * h)
        )

        // Right wing trailing edge
        path.addCurve(
            to: CGPoint(x: 1.0 * w, y: 0.36 * h),
            control1: CGPoint(x: 0.82 * w, y: 0.54 * h),
            control2: CGPoint(x: 0.98 * w, y: 0.50 * h)
        )

        // Right wing leading edge
        path.addCurve(
            to: CGPoint(x: 0.70 * w, y: 0.18 * h),
            control1: CGPoint(x: 1.0 * w, y: 0.22 * h),
            control2: CGPoint(x: 0.86 * w, y: 0.18 * h)
        )

        // Right cephalic fin
        path.addCurve(
            to: CGPoint(x: 0.64 * w, y: 0.0 * h),
            control1: CGPoint(x: 0.70 * w, y: 0.10 * h),
            control2: CGPoint(x: 0.68 * w, y: 0.0 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.5 * w, y: 0.18 * h),
            control1: CGPoint(x: 0.60 * w, y: 0.0 * h),
            control2: CGPoint(x: 0.54 * w, y: 0.08 * h)
        )

        path.closeSubpath()
        return path
    }
}
