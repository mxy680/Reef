import SwiftUI

struct OnboardingProgressBar: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let progress: CGFloat

    private let barHeight: CGFloat = 14
    private let cornerRadius: CGFloat = 7
    private let shadowOffset: CGFloat = 3

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            let fillWidth = max(barHeight, geo.size.width * progress)

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(colors.border, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(colors.shadow)
                            .offset(x: shadowOffset, y: shadowOffset)
                    )

                // Fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ReefColors.primary)
                    .frame(width: fillWidth)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(colors.border, lineWidth: 2)
                    )
            }
        }
        .frame(height: barHeight)
        .animation(.spring(duration: 0.4), value: progress)
    }
}
