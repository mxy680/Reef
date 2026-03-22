import SwiftUI

struct SignUpStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.onboardingStepSpacing) {
                    Spacer()
                        .frame(height: metrics.authVerticalSpacer)

                    Text("Don't let this plan ghost you.")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 0)

                    Text("Create an account so all of this actually saves.")
                        .font(.epilogue(15, weight: .medium))
                        .tracking(-0.04 * 15)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 1)

                    VStack(spacing: 12) {
                        ReefButton(.secondary, action: { auth.signInWithApple() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo")
                                Text("Continue with Apple")
                            }
                        }

                        ReefButton(.secondary, action: { auth.signInWithGoogle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "g.circle.fill")
                                Text("Continue with Google")
                            }
                        }
                    }
                    .frame(maxWidth: 320)
                    .fadeUp(index: 2)

                    // Skip link
                    ReefButton(.ghost, action: { viewModel.goNext() }) {
                        Text("skip for now")
                            .font(.epilogue(13, weight: .medium))
                            .tracking(-0.04 * 13)
                    }
                    .fadeUp(index: 3)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
