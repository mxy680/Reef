import SwiftUI

struct LibraryComingSoonView: View {
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
            LibraryIllustration()
                .frame(width: 200, height: 150)

            VStack(spacing: 6) {
                Text("Library")
                    .font(.epilogue(32, weight: .black))
                    .tracking(-0.04 * 32)
                    .foregroundStyle(ReefColors.black)

                Text("Shared resources and study materials")
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

            Text("Community Library")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(ReefColors.black)
                .padding(.bottom, 10)

            Text("Browse and share study materials with classmates. Find textbooks, problem sets, and notes organized by course \u{2014} all in one place.")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.02 * 15)
                .lineSpacing(4)
                .foregroundStyle(ReefColors.gray600)
                .padding(.bottom, 20)

            // Category grid
            categoryGrid
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    private var comingSoonBadge: some View {
        HStack(spacing: 6) {
            // Flag icon
            Image(systemName: "flag.fill")
                .font(.system(size: 11))
                .foregroundStyle(ReefColors.black)

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

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(categories.enumerated()), id: \.element.label) { index, category in
                categoryCard(category, index: index)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.3).delay(0.45), value: appeared)
    }

    private func categoryCard(_ category: LibraryCategory, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.count)
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)
                .foregroundStyle(ReefColors.black)

            Text(category.label)
                .font(.epilogue(12, weight: .semiBold))
                .tracking(-0.02 * 12)
                .foregroundStyle(ReefColors.gray600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(category.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ReefColors.black, lineWidth: 1.5))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(.easeOut(duration: 0.25).delay(0.5 + Double(index) * 0.06), value: appeared)
    }

    // MARK: - Data

    private struct LibraryCategory {
        let label: String
        let count: String
        let background: Color
    }

    private let categories: [LibraryCategory] = [
        .init(label: "Textbooks", count: "120+", background: ReefColors.accent),
        .init(label: "Problem Sets", count: "85+", background: ReefColors.surface),
        .init(label: "Lecture Notes", count: "200+", background: ReefColors.surface),
        .init(label: "Study Guides", count: "60+", background: ReefColors.accent),
    ]
}

// MARK: - Library Illustration

private struct LibraryIllustration: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 200
            let sy = size.height / 150

            // Shelf line
            var shelf = Path()
            shelf.move(to: p(25, 120, sx, sy))
            shelf.addLine(to: p(175, 120, sx, sy))
            context.stroke(shelf, with: .color(ReefColors.black), lineWidth: 2.5)

            // Book 1 - tall, teal
            let book1 = roundedRect(x: 35, y: 45, w: 22, h: 75, r: 3, sx: sx, sy: sy)
            context.fill(book1, with: .color(ReefColors.accent))
            context.stroke(book1, with: .color(ReefColors.black), lineWidth: 2)
            drawLine(context: context, x1: 40, y1: 55, x2: 52, y2: 55, color: ReefColors.black, width: 1.5, sx: sx, sy: sy)
            drawLine(context: context, x1: 40, y1: 60, x2: 48, y2: 60, color: ReefColors.black, width: 1, sx: sx, sy: sy)
            let label1 = roundedRect(x: 41, y: 95, w: 10, h: 14, r: 2, sx: sx, sy: sy)
            context.fill(label1, with: .color(ReefColors.white))
            context.stroke(label1, with: .color(ReefColors.black), lineWidth: 1)

            // Book 2 - medium, warm
            let book2 = roundedRect(x: 60, y: 55, w: 18, h: 65, r: 3, sx: sx, sy: sy)
            context.fill(book2, with: .color(ReefColors.surface))
            context.stroke(book2, with: .color(ReefColors.black), lineWidth: 2)
            drawLine(context: context, x1: 64, y1: 63, x2: 74, y2: 63, color: ReefColors.black, width: 1.5, sx: sx, sy: sy)
            drawLine(context: context, x1: 64, y1: 68, x2: 71, y2: 68, color: ReefColors.black, width: 1, sx: sx, sy: sy)

            // Book 3 - short, primary
            let book3 = roundedRect(x: 81, y: 70, w: 20, h: 50, r: 3, sx: sx, sy: sy)
            context.fill(book3, with: .color(ReefColors.primary))
            context.stroke(book3, with: .color(ReefColors.black), lineWidth: 2)
            drawLine(context: context, x1: 85, y1: 78, x2: 97, y2: 78, color: ReefColors.white, width: 1.5, sx: sx, sy: sy)
            drawLine(context: context, x1: 85, y1: 83, x2: 93, y2: 83, color: ReefColors.white, width: 1, sx: sx, sy: sy)

            // Book 4 - leaning (rotated -8 degrees around 115, 120)
            let pivotX: CGFloat = 115
            let pivotY: CGFloat = 120
            let angle = -8.0 * .pi / 180.0
            var leaningContext = context
            leaningContext.translateBy(x: pivotX * sx, y: pivotY * sy)
            leaningContext.rotate(by: Angle(radians: angle))
            leaningContext.translateBy(x: -pivotX * sx, y: -pivotY * sy)

            let book4 = roundedRect(x: 105, y: 50, w: 20, h: 70, r: 3, sx: sx, sy: sy)
            leaningContext.fill(book4, with: .color(ReefColors.accent))
            leaningContext.stroke(book4, with: .color(ReefColors.black), lineWidth: 2)

            var line4a = Path()
            line4a.move(to: p(109, 58, sx, sy))
            line4a.addLine(to: p(121, 58, sx, sy))
            leaningContext.stroke(line4a, with: .color(ReefColors.black), lineWidth: 1.5)

            var line4b = Path()
            line4b.move(to: p(109, 63, sx, sy))
            line4b.addLine(to: p(117, 63, sx, sy))
            leaningContext.stroke(line4b, with: .color(ReefColors.black), lineWidth: 1)

            // Book 5 - flat
            let book5 = roundedRect(x: 130, y: 104, w: 35, h: 16, r: 3, sx: sx, sy: sy)
            context.fill(book5, with: .color(ReefColors.surface))
            context.stroke(book5, with: .color(ReefColors.black), lineWidth: 2)
            drawLine(context: context, x1: 135, y1: 112, x2: 155, y2: 112, color: ReefColors.black, width: 1, sx: sx, sy: sy)

            // Open book on stack
            let obx: CGFloat = 135
            let oby: CGFloat = 85

            // Left page
            var leftPage = Path()
            leftPage.move(to: p(obx, oby + 15, sx, sy))
            leftPage.addQuadCurve(to: p(obx + 24, oby + 15, sx, sy), control: p(obx + 12, oby + 8, sx, sy))
            leftPage.addLine(to: p(obx + 24, oby, sx, sy))
            leftPage.addQuadCurve(to: p(obx, oby, sx, sy), control: p(obx + 12, oby - 5, sx, sy))
            leftPage.closeSubpath()
            context.fill(leftPage, with: .color(ReefColors.white))
            context.stroke(leftPage, with: .color(ReefColors.black), lineWidth: 1.5)

            // Right page
            var rightPage = Path()
            rightPage.move(to: p(obx + 24, oby + 15, sx, sy))
            rightPage.addQuadCurve(to: p(obx + 48, oby + 15, sx, sy), control: p(obx + 36, oby + 8, sx, sy))
            rightPage.addLine(to: p(obx + 48, oby, sx, sy))
            rightPage.addQuadCurve(to: p(obx + 24, oby, sx, sy), control: p(obx + 36, oby - 5, sx, sy))
            rightPage.closeSubpath()
            context.fill(rightPage, with: .color(ReefColors.white))
            context.stroke(rightPage, with: .color(ReefColors.black), lineWidth: 1.5)

            // Spine
            drawLine(context: context, x1: obx + 24, y1: oby, x2: obx + 24, y2: oby + 15, color: ReefColors.black, width: 1.5, sx: sx, sy: sy)

            // Text lines on pages
            drawLine(context: context, x1: obx + 4, y1: oby + 5, x2: obx + 18, y2: oby + 5, color: ReefColors.gray400, width: 0.8, sx: sx, sy: sy)
            drawLine(context: context, x1: obx + 4, y1: oby + 8, x2: obx + 15, y2: oby + 8, color: ReefColors.gray400, width: 0.8, sx: sx, sy: sy)
            drawLine(context: context, x1: obx + 30, y1: oby + 5, x2: obx + 44, y2: oby + 5, color: ReefColors.gray400, width: 0.8, sx: sx, sy: sy)
            drawLine(context: context, x1: obx + 30, y1: oby + 8, x2: obx + 41, y2: oby + 8, color: ReefColors.gray400, width: 0.8, sx: sx, sy: sy)

            // Sparkle 1
            drawSparkle(context: context, cx: 50, cy: 25, size: 8, fill: ReefColors.accent, sx: sx, sy: sy)

            // Sparkle 2
            drawSparkle(context: context, cx: 155, cy: 35, size: 6, fill: ReefColors.surface, sx: sx, sy: sy)
        }
    }

    private func p(_ x: CGFloat, _ y: CGFloat, _ sx: CGFloat, _ sy: CGFloat) -> CGPoint {
        CGPoint(x: x * sx, y: y * sy)
    }

    private func roundedRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, sx: CGFloat, sy: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy), cornerRadius: r * min(sx, sy))
    }

    private func drawLine(context: GraphicsContext, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, color: Color, width: CGFloat, sx: CGFloat, sy: CGFloat) {
        var line = Path()
        line.move(to: p(x1, y1, sx, sy))
        line.addLine(to: p(x2, y2, sx, sy))
        context.stroke(line, with: .color(color), lineWidth: width)
    }

    private func drawSparkle(context: GraphicsContext, cx: CGFloat, cy: CGFloat, size: CGFloat, fill: Color, sx: CGFloat, sy: CGFloat) {
        var sparkle = Path()
        sparkle.move(to: p(cx, cy - size, sx, sy))
        sparkle.addLine(to: p(cx + size * 0.25, cy - size * 0.75, sx, sy))
        sparkle.addLine(to: p(cx + size * 0.5, cy, sx, sy))
        sparkle.addLine(to: p(cx + size * 1.25, cy + size * 0.25, sx, sy))
        sparkle.addLine(to: p(cx + size * 0.5, cy + size * 0.5, sx, sy))
        sparkle.addLine(to: p(cx + size * 0.25, cy + size * 1.25, sx, sy))
        sparkle.addLine(to: p(cx, cy + size * 0.5, sx, sy))
        sparkle.addLine(to: p(cx - size * 0.75, cy + size * 0.25, sx, sy))
        sparkle.closeSubpath()
        context.fill(sparkle, with: .color(fill))
        context.stroke(sparkle, with: .color(ReefColors.black), lineWidth: 1)
    }
}
