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
            step: .favoriteTopic,
            title: "What are you studying right now that you actually like?",
            subtitle: "Could be a topic, a chapter, a concept — whatever you're vibing with lately. We're gonna use this.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Illustration
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(ReefColors.primary.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(ReefColors.primary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                ReefTextField(
                    placeholder: placeholder,
                    text: $viewModel.answers.favoriteTopic,
                    capitalization: .sentences,
                    autocorrection: true
                )

                // Suggestion chips
                if viewModel.answers.favoriteTopic.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try one of these:")
                            .font(.epilogue(12, weight: .semiBold))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(colors.textMuted)

                        OnboardingFlowLayout(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewModel.answers.favoriteTopic = suggestion
                                }) {
                                    Text(suggestion)
                                        .font(.epilogue(12, weight: .semiBold))
                                        .tracking(-0.04 * 12)
                                        .foregroundStyle(ReefColors.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(ReefColors.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(NoHighlightButtonStyle())
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
