import SwiftUI

struct LearningStyleStep: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        OnboardingStepShell(
            title: "How do you learn best?",
            subtitle: "Pick your vibe.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 10) {
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

                // Reassurance text after selection
                if viewModel.showLearningStyleReassurance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good news — Reef does all of these.")
                            .font(.epilogue(15, weight: .bold))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(ReefColors.primary)

                        Text("Diagrams, voice explanations, hands-on problem solving, and written breakdowns. We didn't want to pick favorites either.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}
