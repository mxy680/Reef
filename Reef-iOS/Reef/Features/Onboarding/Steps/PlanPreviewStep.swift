import SwiftUI

struct PlanPreviewStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.onboardingStepSpacing) {
                    Spacer()
                        .frame(height: metrics.onboardingStepSpacing)

                    Text("Your study plan is locked in.")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    // Plan card
                    VStack(alignment: .leading, spacing: 16) {
                        planRow(icon: "📚", label: "Courses", value: viewModel.planCoursesLabel)
                        planRow(icon: "🎯", label: "Goal", value: viewModel.planGoalLabel)
                        planRow(icon: "⏰", label: "Daily commitment", value: viewModel.planDailyLabel)
                        planRow(icon: "🧠", label: "Tutor style", value: "Adaptive — visual, audio, hands-on, text")
                        planRow(icon: "💪", label: "Focus areas", value: viewModel.planFocusLabel)
                    }
                    .padding(metrics.reefCardHPadding)
                    .background(colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colors.border, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.shadow)
                            .offset(x: 4, y: 4)
                    )
                    .fadeUp(index: 1)

                    ReefButton("Activate my plan", action: { viewModel.goNext() })
                        .frame(maxWidth: 280)
                        .fadeUp(index: 2)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func planRow(icon: String, label: String, value: String) -> some View {
        let colors = theme.colors
        return HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textMuted)

                Text(value)
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(colors.text)
            }
        }
    }
}
