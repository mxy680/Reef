import SwiftUI

/// A reusable 3D-style slider with a dark track, white fill, and white thumb with a drop shadow.
/// The value is clamped within the provided range via drag gesture.
struct Reef3DSlider: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat>
    var width: CGFloat = 90
    var height: CGFloat = 28
    var trackHeight: CGFloat = 8
    var thumbSize: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let fillWidth = geo.size.width * fraction
            let halfThumb = thumbSize / 2

            ZStack(alignment: .leading) {
                // Track shadow
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.35))
                    .offset(x: 1.5, y: 1.5)

                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.25))

                // Track fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: max(trackHeight, fillWidth))

                // Track border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5)
                    )
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: thumbSize, height: thumbSize)
                            .offset(x: 1.5, y: 1.5)
                    )
                    .offset(x: fillWidth - halfThumb)
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        let pct = max(0, min(1, dragValue.location.x / geo.size.width))
                        value = range.lowerBound + pct * span
                    }
            )
        }
        .frame(width: width, height: height)
    }
}
