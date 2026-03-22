import SwiftUI

struct LearningStyleStep: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        OnboardingStepShell(
            step: .learningStyle,
            title: "How do you learn best?",
            subtitle: "Pick your vibe.",
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

                // Reassurance callout card
                if viewModel.showLearningStyleReassurance {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ReefColors.primary)
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Good news — Reef does all of these.")
                                .font(.epilogue(15, weight: .bold))
                                .tracking(-0.04 * 15)
                                .foregroundStyle(ReefColors.primary)

                            Text("Diagrams, voice explanations, hands-on problem solving, and written breakdowns. We didn't want to pick favorites either.")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(colors.textSecondary)
                        }
                        .padding(.leading, 14)
                        .padding(.vertical, 4)
                    }
                    .padding(16)
                    .background(ReefColors.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }
}
