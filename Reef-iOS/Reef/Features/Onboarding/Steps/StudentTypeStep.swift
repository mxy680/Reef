import SwiftUI

struct StudentTypeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "What Kind of Student Are You?",
            subtitle: "We promise this isn't graded.",
            canAdvance: viewModel.canAdvance,
            showBack: false,
            onBack: nil,
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 12) {
                ForEach(StudentType.allCases, id: \.self) { type in
                    OnboardingOption(
                        label: type.displayLabel,
                        isSelected: viewModel.answers.studentType == type,
                        action: { viewModel.answers.studentType = type }
                    )
                }
            }
        }
    }
}
