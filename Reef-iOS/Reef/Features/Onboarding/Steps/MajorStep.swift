import SwiftUI

struct MajorStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "What Are You Studying?",
            subtitle: "Pick all that apply.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 10) {
                ForEach(MajorField.allCases, id: \.self) { field in
                    let selected = viewModel.answers.majors.contains(field)
                    OnboardingOption(
                        label: field.displayLabel,
                        isSelected: selected,
                        action: {
                            if selected {
                                viewModel.answers.majors.remove(field)
                            } else {
                                viewModel.answers.majors.insert(field)
                            }
                        }
                    )
                }
            }
        }
    }
}
