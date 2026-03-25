import SwiftUI

struct FavoriteTopicStep: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: OnboardingViewModel

    private var suggestions: [String] {
        CourseCatalog.topicSuggestions(for: viewModel.answers.courses)
    }

    var body: some View {
        OnboardingStepShell(
            title: "What kind of problems do you want help with?",
            subtitle: "Pick as many as you want — we'll tailor your experience.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            OnboardingFlowLayout(spacing: 10) {
                ForEach(suggestions, id: \.self) { topic in
                    let selected = viewModel.answers.favoriteTopics.contains(topic)
                    OnboardingPill(
                        label: topic,
                        isSelected: selected,
                        action: {
                            if selected {
                                viewModel.answers.favoriteTopics.remove(topic)
                            } else {
                                viewModel.answers.favoriteTopics.insert(topic)
                            }
                        }
                    )
                }
            }
        }
    }
}
