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
        let colors = theme.colors

        OnboardingStepShell(
            title: "What's the one thing you don't hate studying?",
            subtitle: "We're gonna use this to show you something cool.",
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

            }
        }
    }
}
