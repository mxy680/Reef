import SwiftUI

struct GoalValidationStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.onboardingStepSpacing) {
                    Spacer()
                        .frame(height: metrics.authVerticalSpacer)

                    Text(viewModel.goalValidationHeadline)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 0)

                    VStack(spacing: 12) {
                        Text("Real talk — most students struggle because they're studying alone with zero feedback.")
                            .fadeUp(index: 1)

                        Text("Reef watches your work in real time and jumps in before you spiral. It's like having a TA who actually shows up.")
                            .fadeUp(index: 2)
                    }
                    .font(.epilogue(15, weight: .medium))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)

                    ReefButton("I'm in. Keep going", action: { viewModel.goNext() })
                        .frame(maxWidth: 280)
                        .fadeUp(index: 3)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
