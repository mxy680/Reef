import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ReefTheme.self) private var theme
    @State private var email = ""

    var body: some View {
        @Bindable var auth = auth
        let colors = theme.colors

        ZStack {
            colors.surface
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)

                        authCard(colors)
                            .frame(maxWidth: 480)

                        Spacer(minLength: 60)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    .padding(.horizontal, 24)
                }
            }

            if auth.isLoading {
                loadingOverlay
            }
        }
        .alert(
            "Sign In Error",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )
        ) {
            Button("OK") { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    // MARK: - Auth Card

    @ViewBuilder
    private func authCard(_ colors: ReefThemeColors) -> some View {
        ReefCard {
            VStack(spacing: 0) {
                if auth.magicLinkSent {
                    magicLinkSentContent(colors)
                } else {
                    signInContent(colors)
                }
            }
        }
    }

    // MARK: - Magic Link Sent

    @ViewBuilder
    private func magicLinkSentContent(_ colors: ReefThemeColors) -> some View {
        Image(systemName: "envelope.badge")
            .font(.system(size: 48))
            .foregroundStyle(ReefColors.primary)
            .padding(.bottom, 20)
            .fadeUp(index: 0)

        Text("Check Your Email")
            .reefHeading()
            .multilineTextAlignment(.center)
            .padding(.bottom, 6)
            .fadeUp(index: 1)

        Text("We sent a magic link to \(auth.magicLinkEmail)")
            .reefBody()
            .multilineTextAlignment(.center)
            .padding(.bottom, 28)
            .fadeUp(index: 2)

        ReefButton("Back", variant: .secondary) {
            withAnimation(.easeInOut(duration: 0.3)) {
                auth.magicLinkSent = false
            }
        }
        .fadeUp(index: 3)
    }

    // MARK: - Sign In

    @ViewBuilder
    private func signInContent(_ colors: ReefThemeColors) -> some View {
        Text("Welcome to Reef")
            .reefHeading()
            .multilineTextAlignment(.center)
            .padding(.bottom, 6)
            .fadeUp(index: 0)

        Text("Dive in. Stay afloat. Ace finals.")
            .reefBody()
            .multilineTextAlignment(.center)
            .padding(.bottom, 28)
            .fadeUp(index: 1)

        oauthButtons(colors)

        ReefDivider()
            .padding(.bottom, 20)
            .fadeUp(index: 3)

        ReefTextField(
            placeholder: "name@example.com",
            text: $email,
            icon: "envelope",
            keyboard: .emailAddress,
            onSubmit: { auth.sendMagicLink(email: email) }
        )
        .padding(.bottom, 22)
        .fadeUp(index: 4)

        ReefButton(
            "Continue with Email",
            variant: .primary,
            disabled: email.isEmpty || auth.isLoading
        ) {
            auth.sendMagicLink(email: email)
        }
        .fadeUp(index: 5)

        #if DEBUG
        ReefButton("Dev Login", variant: .link) {
            auth.devLogin()
        }
        .padding(.top, 16)
        #endif
    }

    // MARK: - OAuth Buttons

    @ViewBuilder
    private func oauthButtons(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 12) {
            ReefButton(.secondary, action: { auth.signInWithGoogle() }) {
                HStack(spacing: 10) {
                    GoogleIcon()
                    Text("Google")
                }
            }
            .accessibilityLabel("Sign in with Google")

            ReefButton(.secondary, action: { auth.signInWithApple() }) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Apple")
                }
            }
            .accessibilityLabel("Sign in with Apple")
        }
        .padding(.bottom, 20)
        .fadeUp(index: 2)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
}

// MARK: - Preview Mocks

#if DEBUG
private struct MockAuthRepo: AuthRepository {
    func authStateChanges() -> AsyncStream<AuthSession?> { .init { $0.finish() } }
    func restoreSession() async throws -> AuthSession { throw CancellationError() }
    func signInWithApple(idToken: String, nonce: String) async throws {}
    func signInWithGoogle(idToken: String, accessToken: String) async throws {}
    func sendMagicLink(email: String) async throws {}
    func handleURL(_ url: URL) async throws {}
    func signOut() async throws {}
}

private struct MockProfileRepo: ProfileRepository {
    func fetchProfile() async throws -> Profile? { nil }
    func upsertProfile(_ update: ProfileUpdate) async throws {}
}
#endif

#Preview {
    AuthView()
        .environment(
            AuthViewModel(
                authRepo: MockAuthRepo(),
                profileRepo: MockProfileRepo()
            )
        )
        .environment(ReefTheme())
}
