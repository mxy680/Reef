import SwiftUI

struct MyReefComingSoonView: View {
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Illustration area
                illustrationArea

                // Content area
                contentArea
            }
        }
        .dashboardCard()
        .onAppear { appeared = true }
    }

    // MARK: - Illustration

    private var illustrationArea: some View {
        VStack(spacing: 24) {
            CoralReefIllustration()
                .frame(width: 200, height: 160)

            VStack(spacing: 6) {
                Text("My Reef")
                    .font(.epilogue(32, weight: .black))
                    .tracking(-0.04 * 32)
                    .foregroundStyle(ReefColors.black)

                Text("Your personal ocean ecosystem")
                    .font(.epilogue(15, weight: .medium))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(ReefColors.gray600)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(ReefColors.accent)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ReefColors.gray500)
                .frame(height: 1.5)
        }
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Badge
            comingSoonBadge
                .padding(.bottom, 16)

            Text("Build Your Reef Ecosystem")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(ReefColors.black)
                .padding(.bottom, 10)

            Text("As you study and master new topics, you'll unlock species for your personal reef. Watch your ocean grow from a quiet sandy floor into a thriving coral ecosystem.")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.02 * 15)
                .lineSpacing(4)
                .foregroundStyle(ReefColors.gray600)
                .padding(.bottom, 20)

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.element.label) { index, feature in
                    featureRow(feature, index: index)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    private var comingSoonBadge: some View {
        HStack(spacing: 6) {
            // Star icon
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(ReefColors.accent)
                .overlay(
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundStyle(ReefColors.black)
                )

            Text("COMING SOON")
                .font(.epilogue(11, weight: .bold))
                .tracking(0.04 * 11)
                .foregroundStyle(ReefColors.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(ReefColors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(ReefColors.black, lineWidth: 2))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .animation(.easeOut(duration: 0.3).delay(0.35), value: appeared)
    }

    private func featureRow(_ feature: ReefFeature, index: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(feature.color)
                .overlay(Circle().stroke(ReefColors.black, lineWidth: 1.5))
                .frame(width: 8, height: 8)

            Text(feature.label)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.02 * 14)
                .foregroundStyle(ReefColors.black)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -12)
        .animation(.easeOut(duration: 0.3).delay(0.45 + Double(index) * 0.08), value: appeared)
    }

    // MARK: - Data

    private struct ReefFeature {
        let label: String
        let color: Color
    }

    private let features: [ReefFeature] = [
        .init(label: "Unlock species as you learn", color: ReefColors.accent),
        .init(label: "Track mastery across subjects", color: ReefColors.surface),
        .init(label: "Compare reefs with friends", color: ReefColors.accent),
    ]
}

// MARK: - Coral Reef Illustration

private struct CoralReefIllustration: View {
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 200
            let scaleY = size.height / 160

            // Ocean floor
            var floor = Path()
            floor.move(to: CGPoint(x: 0 * scaleX, y: 140 * scaleY))
            floor.addQuadCurve(
                to: CGPoint(x: 100 * scaleX, y: 135 * scaleY),
                control: CGPoint(x: 50 * scaleX, y: 130 * scaleY)
            )
            floor.addQuadCurve(
                to: CGPoint(x: 200 * scaleX, y: 132 * scaleY),
                control: CGPoint(x: 150 * scaleX, y: 140 * scaleY)
            )
            floor.addLine(to: CGPoint(x: 200 * scaleX, y: 160 * scaleY))
            floor.addLine(to: CGPoint(x: 0 * scaleX, y: 160 * scaleY))
            floor.closeSubpath()
            context.fill(floor, with: .color(ReefColors.accent))
            context.stroke(floor, with: .color(ReefColors.black), lineWidth: 2)

            // Coral branch 1
            var coral1a = Path()
            coral1a.move(to: p(40, 140, scaleX, scaleY))
            coral1a.addQuadCurve(to: p(30, 90, scaleX, scaleY), control: p(38, 110, scaleX, scaleY))
            coral1a.addQuadCurve(to: p(40, 60, scaleX, scaleY), control: p(25, 80, scaleX, scaleY))
            coral1a.addQuadCurve(to: p(45, 45, scaleX, scaleY), control: p(35, 50, scaleX, scaleY))
            context.stroke(coral1a, with: .color(ReefColors.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            var coral1b = Path()
            coral1b.move(to: p(40, 140, scaleX, scaleY))
            coral1b.addQuadCurve(to: p(50, 100, scaleX, scaleY), control: p(42, 115, scaleX, scaleY))
            coral1b.addQuadCurve(to: p(45, 85, scaleX, scaleY), control: p(55, 90, scaleX, scaleY))
            context.stroke(coral1b, with: .color(ReefColors.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Coral tips
            drawCircle(context: context, cx: 45, cy: 45, r: 5, fill: ReefColors.accent, scaleX: scaleX, scaleY: scaleY)
            drawCircle(context: context, cx: 30, cy: 75, r: 4, fill: ReefColors.accent, scaleX: scaleX, scaleY: scaleY)

            // Coral branch 2 - fan
            let coral2Color = Color(red: 232 / 255, green: 132 / 255, blue: 124 / 255) // #E8847C
            for (startX, endX, endY): (CGFloat, CGFloat, CGFloat) in [(120, 105, 80), (120, 120, 75), (120, 135, 80)] {
                var fan = Path()
                fan.move(to: p(startX, 135, scaleX, scaleY))
                fan.addQuadCurve(
                    to: p(endX, endY, scaleX, scaleY),
                    control: p((startX + endX) / 2, 100, scaleX, scaleY)
                )
                context.stroke(fan, with: .color(coral2Color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            drawCircle(context: context, cx: 105, cy: 77, r: 4, fill: ReefColors.surface, scaleX: scaleX, scaleY: scaleY)
            drawCircle(context: context, cx: 120, cy: 72, r: 4, fill: ReefColors.surface, scaleX: scaleX, scaleY: scaleY)
            drawCircle(context: context, cx: 135, cy: 77, r: 4, fill: ReefColors.surface, scaleX: scaleX, scaleY: scaleY)

            // Seaweed
            var seaweed = Path()
            seaweed.move(to: p(170, 140, scaleX, scaleY))
            seaweed.addQuadCurve(to: p(165, 105, scaleX, scaleY), control: p(175, 120, scaleX, scaleY))
            seaweed.addQuadCurve(to: p(165, 75, scaleX, scaleY), control: p(155, 90, scaleX, scaleY))
            seaweed.addQuadCurve(to: p(168, 45, scaleX, scaleY), control: p(175, 60, scaleX, scaleY))
            context.stroke(seaweed, with: .color(ReefColors.accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Fish (large)
            let fishBody = Path(ellipseIn: CGRect(
                x: (80 - 12) * scaleX, y: (50 - 7) * scaleY,
                width: 24 * scaleX, height: 14 * scaleY
            ))
            context.fill(fishBody, with: .color(ReefColors.surface))
            context.stroke(fishBody, with: .color(ReefColors.black), lineWidth: 1.5)

            var fishTail = Path()
            fishTail.move(to: p(92, 50, scaleX, scaleY))
            fishTail.addLine(to: p(100, 44, scaleX, scaleY))
            fishTail.addLine(to: p(100, 56, scaleX, scaleY))
            fishTail.closeSubpath()
            context.fill(fishTail, with: .color(ReefColors.surface))
            context.stroke(fishTail, with: .color(ReefColors.black), lineWidth: 1.5)

            let fishEye = Path(ellipseIn: CGRect(
                x: (75 - 1.5) * scaleX, y: (49 - 1.5) * scaleY,
                width: 3 * scaleX, height: 3 * scaleY
            ))
            context.fill(fishEye, with: .color(ReefColors.black))

            // Small fish
            let smallFish = Path(ellipseIn: CGRect(
                x: (155 - 8) * scaleX, y: (35 - 5) * scaleY,
                width: 16 * scaleX, height: 10 * scaleY
            ))
            context.fill(smallFish, with: .color(ReefColors.accent))
            context.stroke(smallFish, with: .color(ReefColors.black), lineWidth: 1.5)

            var smallTail = Path()
            smallTail.move(to: p(163, 35, scaleX, scaleY))
            smallTail.addLine(to: p(169, 30, scaleX, scaleY))
            smallTail.addLine(to: p(169, 40, scaleX, scaleY))
            smallTail.closeSubpath()
            context.fill(smallTail, with: .color(ReefColors.accent))
            context.stroke(smallTail, with: .color(ReefColors.black), lineWidth: 1.5)

            let smallEye = Path(ellipseIn: CGRect(
                x: (151 - 1) * scaleX, y: (34 - 1) * scaleY,
                width: 2 * scaleX, height: 2 * scaleY
            ))
            context.fill(smallEye, with: .color(ReefColors.black))

            // Bubbles
            drawBubble(context: context, cx: 60, cy: 25, r: 3, scaleX: scaleX, scaleY: scaleY)
            drawBubble(context: context, cx: 140, cy: 18, r: 2, scaleX: scaleX, scaleY: scaleY)
            drawBubble(context: context, cx: 95, cy: 12, r: 2.5, scaleX: scaleX, scaleY: scaleY)
        }
    }

    private func p(_ x: CGFloat, _ y: CGFloat, _ sx: CGFloat, _ sy: CGFloat) -> CGPoint {
        CGPoint(x: x * sx, y: y * sy)
    }

    private func drawCircle(context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, fill: Color, scaleX: CGFloat, scaleY: CGFloat) {
        let circle = Path(ellipseIn: CGRect(
            x: (cx - r) * scaleX, y: (cy - r) * scaleY,
            width: 2 * r * scaleX, height: 2 * r * scaleY
        ))
        context.fill(circle, with: .color(fill))
        context.stroke(circle, with: .color(ReefColors.black), lineWidth: 1.5)
    }

    private func drawBubble(context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, scaleX: CGFloat, scaleY: CGFloat) {
        let bubble = Path(ellipseIn: CGRect(
            x: (cx - r) * scaleX, y: (cy - r) * scaleY,
            width: 2 * r * scaleX, height: 2 * r * scaleY
        ))
        context.stroke(bubble, with: .color(ReefColors.gray400), lineWidth: 1)
    }
}
