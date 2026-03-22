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
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ReefColors.primary)
                            .frame(width: 4, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good news — Reef does all of these.")
                                .font(.epilogue(14, weight: .bold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.primary)

                            Text("Diagrams, voice, hands-on, and text. We didn't want to pick favorites either.")
                                .font(.epilogue(12, weight: .medium))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(ReefColors.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }
}
