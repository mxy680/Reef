import SwiftUI

// MARK: - Ruler Overlay View

struct CanvasRulerOverlayView: View {
    var isDarkMode: Bool = false

    private let baseWidth: CGFloat = 600
    private let baseHeight: CGFloat = 56

    @State private var position: CGPoint = .zero
    @State private var rotation: Angle = .zero
    @State private var scale: CGFloat = 1.0

    @State private var dragOffset: CGSize = .zero
    @State private var rotationDelta: Angle = .zero
    @State private var scaleDelta: CGFloat = 1.0
    @State private var initialPosition: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let center = initialPosition ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            rulerBody
                .scaleEffect(scale * scaleDelta)
                .position(
                    x: (initialPosition == nil ? center.x : position.x) + dragOffset.width,
                    y: (initialPosition == nil ? center.y : position.y) + dragOffset.height
                )
                .rotationEffect(rotation + rotationDelta)
                .gesture(dragGesture)
                .simultaneousGesture(rotationGesture)
                .simultaneousGesture(magnificationGesture)
                .onAppear {
                    if initialPosition == nil {
                        position = center
                        initialPosition = center
                    }
                }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Theme Colors

    private var rulerFill: Color {
        isDarkMode
            ? Color(red: 0.22, green: 0.24, blue: 0.28)
            : Color(red: 0.96, green: 0.88, blue: 0.55)
    }

    private var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.25) : Color.black.opacity(0.35)
    }

    private var tickColor: Color {
        isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
    }

    private var labelColor: Color {
        isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
    }

    private var edgeColor: Color {
        isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
    }

    // MARK: - Ruler Body

    private var rulerBody: some View {
        let tick = tickColor
        let label = labelColor
        let edge = edgeColor

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(rulerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1.5)
                )

            Canvas { context, size in
                let shortTick: CGFloat = 10
                let medTick: CGFloat = 16
                let longTick: CGFloat = 24

                let ptPerCm: CGFloat = 72.0 / 2.54
                let totalCm = Int(size.width / ptPerCm)

                for cm in 0...totalCm {
                    let baseX = CGFloat(cm) * ptPerCm + 16
                    guard baseX < size.width - 8 else { break }

                    var longPath = Path()
                    longPath.move(to: CGPoint(x: baseX, y: 0))
                    longPath.addLine(to: CGPoint(x: baseX, y: longTick))
                    context.stroke(longPath, with: .color(tick), lineWidth: 1.2)

                    if cm > 0 {
                        let text = Text("\(cm)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(label)
                        context.draw(
                            context.resolve(text),
                            at: CGPoint(x: baseX, y: longTick + 8),
                            anchor: .center
                        )
                    }

                    let ptPerMm = ptPerCm / 10.0
                    for mm in 1..<10 {
                        let x = baseX + CGFloat(mm) * ptPerMm
                        guard x < size.width - 8 else { break }

                        let tickH = mm == 5 ? medTick : shortTick
                        var mmPath = Path()
                        mmPath.move(to: CGPoint(x: x, y: 0))
                        mmPath.addLine(to: CGPoint(x: x, y: tickH))
                        context.stroke(mmPath, with: .color(tick), lineWidth: mm == 5 ? 0.8 : 0.5)
                    }
                }

                var edgePath = Path()
                edgePath.move(to: CGPoint(x: 0, y: size.height))
                edgePath.addLine(to: CGPoint(x: size.width, y: size.height))
                context.stroke(edgePath, with: .color(edge), lineWidth: 2)
            }
        }
        .frame(width: baseWidth, height: baseHeight)
        .shadow(color: .black.opacity(isDarkMode ? 0.4 : 0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in
                position.x += value.translation.width
                position.y += value.translation.height
                dragOffset = .zero
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in rotationDelta = angle }
            .onEnded { angle in
                rotation = rotation + angle
                rotationDelta = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in scaleDelta = value.magnification }
            .onEnded { value in
                scale = max(0.5, min(scale * value.magnification, 3.0))
                scaleDelta = 1.0
            }
    }
}
