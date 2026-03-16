import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ReefTheme.self) private var theme
    @State private var isSignUp = false
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

                        if isSignUp {
                            valueProps(colors)
                        }

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

        Button("Back") {
            withAnimation(.easeInOut(duration: 0.3)) {
                auth.magicLinkSent = false
            }
        }
        .reefStyle(.secondary)
        .fadeUp(index: 3)
    }

    // MARK: - Sign In / Sign Up Form

    @ViewBuilder
    private func signInContent(_ colors: ReefThemeColors) -> some View {
        Text(isSignUp ? "Get Started" : "Welcome Back")
            .reefHeading()
            .multilineTextAlignment(.center)
            .padding(.bottom, 6)
            .fadeUp(index: 0)

        Text(isSignUp ? "Create your free account" : "Sign in to continue learning")
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

        Button(isSignUp ? "Create Account" : "Continue") {
            auth.sendMagicLink(email: email)
        }
        .reefStyle(.primary)
        .disabled(email.isEmpty || auth.isLoading)
        .padding(.bottom, 20)
        .fadeUp(index: 5)

        toggleLink(colors)

        #if DEBUG
        Button("Dev Login") {
            auth.devLogin()
        }
        .reefStyle(.link)
        .padding(.top, 16)
        #endif
    }

    // MARK: - OAuth Buttons

    @ViewBuilder
    private func oauthButtons(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 12) {
            Button {
                auth.signInWithGoogle()
            } label: {
                HStack(spacing: 10) {
                    GoogleIcon()
                    Text("Google")
                }
            }
            .reefStyle(.secondary)

            Button {
                auth.signInWithApple()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Apple")
                }
            }
            .reefStyle(.secondary)
        }
        .disabled(auth.isLoading)
        .padding(.bottom, 20)
        .fadeUp(index: 2)
    }

    // MARK: - Toggle Link

    @ViewBuilder
    private func toggleLink(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 4) {
            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                .reefLabel()
                .foregroundStyle(colors.textSecondary)

            Button(isSignUp ? "Log in" : "Sign up") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSignUp.toggle()
                    email = ""
                }
            }
            .reefStyle(.link)
        }
        .fadeUp(index: 6)
    }

    // MARK: - Value Props

    @ViewBuilder
    private func valueProps(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 24) {
            ForEach(
                ["Free during beta", "Works with any subject", "No credit card required"],
                id: \.self
            ) { text in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ReefColors.primary)

                    Text(text)
                        .reefCaption()
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
        .padding(.top, 28)
        .transition(.opacity)
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

#Preview {
    AuthView()
        .environment(
            AuthViewModel(
                authRepo: SupabaseAuthRepository(),
                profileRepo: SupabaseProfileRepository()
            )
        )
        .environment(ReefTheme())
}
