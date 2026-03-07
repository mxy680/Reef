//
//  RulerOverlayView.swift
//  Reef
//
//  Draggable + rotatable ruler overlay for the canvas
//

import SwiftUI

struct RulerOverlayView: View {
    /// Base ruler dimensions
    private let baseWidth: CGFloat = 600
    private let baseHeight: CGFloat = 56

    @State private var position: CGPoint = .zero
    @State private var rotation: Angle = .zero
    @State private var scale: CGFloat = 1.0

    // Gesture tracking
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

    // MARK: - Ruler Body

    private var rulerBody: some View {
        ZStack(alignment: .top) {
            // Translucent ruler background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.96, green: 0.88, blue: 0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1.5)
                )

            // Tick marks and numbers
            Canvas { context, size in
                let tickColor = Color.black.opacity(0.7)
                let shortTick: CGFloat = 10
                let medTick: CGFloat = 16
                let longTick: CGFloat = 24

                // Points per cm at 72 dpi (1 inch = 2.54cm, 1 inch = 72pt)
                let ptPerCm: CGFloat = 72.0 / 2.54
                let totalCm = Int(size.width / ptPerCm)

                for cm in 0...totalCm {
                    let baseX = CGFloat(cm) * ptPerCm + 16 // 16pt left padding

                    guard baseX < size.width - 8 else { break }

                    // Draw cm tick (tall)
                    var longPath = Path()
                    longPath.move(to: CGPoint(x: baseX, y: 0))
                    longPath.addLine(to: CGPoint(x: baseX, y: longTick))
                    context.stroke(longPath, with: .color(tickColor), lineWidth: 1.2)

                    // Number label
                    if cm > 0 {
                        let text = Text("\(cm)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.6))
                        context.draw(
                            context.resolve(text),
                            at: CGPoint(x: baseX, y: longTick + 8),
                            anchor: .center
                        )
                    }

                    // Draw mm ticks within this cm
                    let ptPerMm = ptPerCm / 10.0
                    for mm in 1..<10 {
                        let x = baseX + CGFloat(mm) * ptPerMm
                        guard x < size.width - 8 else { break }

                        let tickH = mm == 5 ? medTick : shortTick
                        var mmPath = Path()
                        mmPath.move(to: CGPoint(x: x, y: 0))
                        mmPath.addLine(to: CGPoint(x: x, y: tickH))
                        context.stroke(mmPath, with: .color(tickColor), lineWidth: mm == 5 ? 0.8 : 0.5)
                    }
                }

                // Bottom edge line (the straight edge for drawing)
                var edgePath = Path()
                edgePath.move(to: CGPoint(x: 0, y: size.height))
                edgePath.addLine(to: CGPoint(x: size.width, y: size.height))
                context.stroke(edgePath, with: .color(Color.black.opacity(0.5)), lineWidth: 2)
            }
        }
        .frame(width: baseWidth, height: baseHeight)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                position.x += value.translation.width
                position.y += value.translation.height
                dragOffset = .zero
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotationDelta = angle
            }
            .onEnded { angle in
                rotation = rotation + angle
                rotationDelta = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scaleDelta = value.magnification
            }
            .onEnded { value in
                scale = max(0.5, min(scale * value.magnification, 3.0))
                scaleDelta = 1.0
            }
    }
}
