import SwiftUI

/// Subtle dot grid pattern drawn behind onboarding screens.
struct OnboardingDotGrid: View {
    @Environment(ReefTheme.self) private var theme

    private let dotSize: CGFloat = 2
    private let spacing: CGFloat = 28

    var body: some View {
        let colors = theme.colors

        Canvas { context, size in
            let dotColor = colors.border.opacity(0.15)
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing + spacing / 2
                    let y = CGFloat(row) * spacing + spacing / 2
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(dotColor)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
