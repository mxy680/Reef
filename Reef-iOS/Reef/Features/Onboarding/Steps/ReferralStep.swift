import SwiftUI

struct ReferralStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "Who do we owe a thank you?",
            subtitle: "Just curious. Then you're in.",
            canAdvance: viewModel.canAdvance,
            forwardLabel: "I'm done. Let me in.",
            showBack: true,
            onBack: { viewModel.goBack() },
            onForward: {
                Task {
                    await viewModel.submitOnboarding()
                }
            }
        ) {
            VStack(spacing: 10) {
                ForEach(ReferralSource.allCases, id: \.self) { source in
                    OnboardingOption(
                        label: source.displayLabel,
                        isSelected: viewModel.answers.referralSource == source,
                        action: { viewModel.answers.referralSource = source }
                    )
                }

                // Referral code
                ReefTextField(
                    placeholder: "Got a referral code?",
                    text: $viewModel.answers.referralCode
                )
                .padding(.top, 8)
            }
        }
    }
}
