import SwiftUI

struct DailyGoalStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "How much studying are we talking?",
            subtitle: "Pick a daily goal. We'll gently haunt you about it.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 10) {
                ForEach(DailyGoalOption.allCases, id: \.self) { option in
                    OnboardingOption(
                        label: option.displayLabel,
                        subtitle: option.subtitle,
                        isSelected: viewModel.answers.dailyGoal == option,
                        action: { viewModel.answers.dailyGoal = option }
                    )
                }
            }
        }
    }
}
