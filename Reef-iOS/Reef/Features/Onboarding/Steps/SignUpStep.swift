import SwiftUI

struct SignUpStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Logo
                    Text("REEF")
                        .font(.epilogue(20, weight: .black))
                        .tracking(8)
                        .foregroundStyle(ReefColors.primary)
                        .fadeUp(index: 0)

                    Text("Don't let this plan\nghost you.")
                        .font(.epilogue(32, weight: .black))
                        .tracking(-0.04 * 32)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 1)

                    Text("Create an account so all of this actually saves.")
                        .font(.epilogue(16, weight: .medium))
                        .tracking(-0.04 * 16)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 2)

                    VStack(spacing: 14) {
                        ReefButton(.secondary, action: { auth.signInWithApple() }) {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Apple")
                            }
                        }

                        ReefButton(.secondary, action: { auth.signInWithGoogle() }) {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Google")
                            }
                        }
                    }
                    .frame(maxWidth: 360)
                    .fadeUp(index: 3)

                    // Skip link
                    Button(action: { viewModel.goNext() }) {
                        Text("skip for now")
                            .font(.epilogue(13, weight: .medium))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(colors.textMuted)
                    }
                    .buttonStyle(NoHighlightButtonStyle())
                    .fadeUp(index: 4)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            // Skip this screen if already authenticated
            if auth.isAuthenticated {
                Task { @MainActor in
                    viewModel.goNext()
                }
            }
        }
    }
}
