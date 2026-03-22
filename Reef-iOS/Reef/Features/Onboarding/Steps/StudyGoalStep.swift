import SwiftUI

struct StudyGoalStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            step: .studyGoal,
            title: "What's the dream?",
            subtitle: "Be honest. We won't tell anyone.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 12) {
                ForEach(StudyGoal.allCases, id: \.self) { goal in
                    OnboardingOption(
                        label: goal.displayLabel,
                        icon: goal.icon,
                        isSelected: viewModel.answers.studyGoal == goal,
                        action: { viewModel.answers.studyGoal = goal }
                    )
                }
            }
        }
    }
}
