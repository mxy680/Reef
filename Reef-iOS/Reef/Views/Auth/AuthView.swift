import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isSignUp = false
    @State private var email = ""

    var body: some View {
        ZStack {
            ReefColors.surface
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Card
                    ReefCard {
                        VStack(spacing: 0) {
                            // Title
                            Text(isSignUp ? "Get Started" : "Welcome Back")
                                .reefHeading()
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 6)
                                .fadeUp(index: 0)

                            // Subtitle
                            Text(isSignUp ? "Create your free account" : "Sign in to continue learning")
                                .reefBody()
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 28)
                                .fadeUp(index: 1)

                            // OAuth buttons
                            HStack(spacing: 12) {
                                Button {
                                    // Google sign-in (not wired)
                                } label: {
                                    HStack(spacing: 10) {
                                        GoogleIcon()
                                        Text("Google")
                                    }
                                }
                                .reefStyle(.secondary)

                                Button {
                                    authManager.signInWithApple()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Apple")
                                    }
                                }
                                .reefStyle(.secondary)
                            }
                            .disabled(authManager.isLoading)
                            .padding(.bottom, 20)
                            .fadeUp(index: 2)

                            // Divider
                            ReefDivider()
                                .padding(.bottom, 20)
                                .fadeUp(index: 3)

                            // Email field
                            ReefTextField(
                                placeholder: isSignUp ? "Email" : "Enter your email",
                                text: $email
                            )
                            .padding(.bottom, 22)
                            .fadeUp(index: 4)

                            // CTA button
                            Button {
                                // Auth action (not wired)
                            } label: {
                                Text(isSignUp ? "Create Account" : "Continue")
                            }
                            .reefStyle(.primary)
                            .padding(.bottom, 20)
                            .fadeUp(index: 5)

                            // Toggle link
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .font(.epilogue(14, weight: .medium))
                                    .tracking(-0.04 * 14)
                                    .foregroundStyle(ReefColors.gray600)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isSignUp.toggle()
                                        email = ""
                                    }
                                } label: {
                                    Text(isSignUp ? "Log in" : "Sign up")
                                        .font(.epilogue(14, weight: .bold))
                                        .tracking(-0.04 * 14)
                                        .foregroundStyle(ReefColors.primary)
                                }
                            }
                            .fadeUp(index: 6)
                        }
                    }
                    .frame(maxWidth: 480)

                    // Value props (signup only)
                    if isSignUp {
                        HStack(spacing: 24) {
                            ForEach(["Free during beta", "Works with any subject", "No credit card required"], id: \.self) { text in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(ReefColors.primary)

                                    Text(text)
                                        .font(.epilogue(13, weight: .medium))
                                        .tracking(-0.02 * 13)
                                        .foregroundStyle(ReefColors.gray600)
                                }
                            }
                        }
                        .padding(.top, 28)
                        .transition(.opacity)
                    }

                    Spacer(minLength: 60)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }

            if authManager.isLoading {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .alert("Sign In Error",
               isPresented: Binding(
                   get: { authManager.errorMessage != nil },
                   set: { if !$0 { authManager.errorMessage = nil } }
               )) {
            Button("OK") { authManager.errorMessage = nil }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthManager())
}
