import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors
        let topic = viewModel.answers.favoriteTopic.isEmpty
            ? "your favorite topic"
            : viewModel.answers.favoriteTopic

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.onboardingStepSpacing) {
                    Spacer()
                        .frame(height: metrics.authVerticalSpacer / 2)

                    Text("Alright, let's see what this thing can do.")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    Text("Here's a \(topic) problem, since you said that's your thing.")
                        .font(.epilogue(15, weight: .medium))
                        .tracking(-0.04 * 15)
                        .foregroundStyle(colors.textSecondary)
                        .fadeUp(index: 1)

                    // Placeholder for tutor demo
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ReefColors.primary.opacity(0.3))

                        Text("Tutor demo loading...")
                            .font(.epilogue(14, weight: .semiBold))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(colors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colors.border, lineWidth: 2)
                    )
                    .fadeUp(index: 2)

                    ReefButton("Done — show me my plan", action: { viewModel.goNext() })
                        .frame(maxWidth: 300)
                        .fadeUp(index: 3)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
