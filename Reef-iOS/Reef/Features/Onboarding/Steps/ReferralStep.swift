import SwiftUI

struct ReferralStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "Last one, promise — how'd you find us?",
            canAdvance: viewModel.canAdvance,
            forwardLabel: "Let's study",
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
