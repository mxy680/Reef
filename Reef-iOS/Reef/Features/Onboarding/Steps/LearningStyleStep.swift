import SwiftUI

struct LearningStyleStep: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        OnboardingStepShell(
            title: "How Do You Learn Best?",
            subtitle: "Spoiler: we do all of them.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 12) {
                ForEach(LearningStyle.allCases, id: \.self) { style in
                    OnboardingOption(
                        label: style.displayLabel,
                        icon: style.icon,
                        isSelected: viewModel.answers.learningStyle == style,
                        action: {
                            viewModel.answers.learningStyle = style
                            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                                viewModel.showLearningStyleReassurance = true
                            }
                        }
                    )
                }

            }
        }
    }
}
