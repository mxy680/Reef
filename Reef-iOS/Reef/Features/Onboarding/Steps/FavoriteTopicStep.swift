import SwiftUI

struct FavoriteTopicStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private var placeholder: String {
        CourseCatalog.topicPlaceholder(for: viewModel.answers.courses)
    }

    var body: some View {
        OnboardingStepShell(
            title: "What are you studying right now that you actually like?",
            subtitle: "Could be a topic, a chapter, a concept — whatever you're vibing with lately. We're gonna use this.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            ReefTextField(
                placeholder: placeholder,
                text: $viewModel.answers.favoriteTopic,
                capitalization: .sentences,
                autocorrection: true
            )
        }
    }
}
