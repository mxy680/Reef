import SwiftUI

struct StudentTypeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            step: .studentType,
            title: "Real quick — what are you?",
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
