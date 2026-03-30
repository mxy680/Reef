import SwiftUI

struct DailyGoalStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "How Much Time Can You Put In?",
            subtitle: "Set a daily goal — we'll help you stick to it.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 12) {
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
