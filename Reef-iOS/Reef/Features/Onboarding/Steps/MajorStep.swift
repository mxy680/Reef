import SwiftUI

struct MajorStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            step: .major,
            title: "What's your field?",
            subtitle: "Don't overthink it. Broad strokes.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 10) {
                ForEach(MajorField.allCases, id: \.self) { field in
                    OnboardingOption(
                        label: field.displayLabel,
                        isSelected: viewModel.answers.major == field,
                        action: { viewModel.answers.major = field }
                    )
                }
            }
        }
    }
}
