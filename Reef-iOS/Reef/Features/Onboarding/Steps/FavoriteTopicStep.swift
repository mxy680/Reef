import SwiftUI

struct FavoriteTopicStep: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: OnboardingViewModel

    private var placeholder: String {
        CourseCatalog.topicPlaceholder(for: viewModel.answers.courses)
    }

    private var suggestions: [String] {
        CourseCatalog.topicSuggestions(for: viewModel.answers.courses)
    }

    var body: some View {
        OnboardingStepShell(
            title: "What Topic Keeps You Up at Night?",
            subtitle: "We'll tailor your experience around this.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ReefTextField(
                    placeholder: placeholder,
                    text: $viewModel.answers.favoriteTopic,
                    capitalization: .sentences,
                    autocorrection: true
                )

                // Suggestion pills — tap to fill in
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("or pick one")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.colors.textMuted)

                        OnboardingFlowLayout(spacing: 8) {
                            ForEach(suggestions, id: \.self) { topic in
                                let isActive = viewModel.answers.favoriteTopic.lowercased() == topic.lowercased()
                                OnboardingPill(
                                    label: topic,
                                    isSelected: isActive,
                                    action: {
                                        viewModel.answers.favoriteTopic = topic
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
