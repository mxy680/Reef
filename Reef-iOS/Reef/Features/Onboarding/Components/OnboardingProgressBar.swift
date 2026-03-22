import SwiftUI

struct OnboardingProgressBar: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let colors = theme.colors
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: metrics.onboardingProgressHeight / 2)
                    .fill(colors.subtle)

                RoundedRectangle(cornerRadius: metrics.onboardingProgressHeight / 2)
                    .fill(ReefColors.primary)
                    .frame(width: max(metrics.onboardingProgressHeight, geo.size.width * progress))
            }
        }
        .frame(height: metrics.onboardingProgressHeight)
        .animation(.spring(duration: 0.4), value: progress)
    }
}
