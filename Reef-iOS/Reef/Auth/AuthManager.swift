import AuthenticationServices
import CryptoKit
import Foundation
@preconcurrency import GoogleSignIn
import Supabase

@Observable
@MainActor
final class AuthManager {
    var session: Session?
    var profile: Profile?
    var isLoading = false
    var errorMessage: String?
    var magicLinkSent = false
    var magicLinkEmail = ""

    var isAuthenticated: Bool { session != nil }
    var onboardingCompleted: Bool { profile?.onboardingCompleted == true }

    private var coordinator: AppleSignInCoordinator?
    private var currentNonce: String?
    private let profileManager = ProfileManager()

    init() {
        Task { await bootstrap() }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        // Listen for auth state changes
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                self.session = session
                if session != nil, event == .signedIn || event == .tokenRefreshed || event == .initialSession {
                    await checkOnboarding()
                }
                if session == nil {
                    self.profile = nil
                }
            }
        }

        // Attempt session restore
        do {
            session = try await supabase.auth.session
            await checkOnboarding()
        } catch {
            session = nil
        }
    }

    // MARK: - Onboarding

    private func checkOnboarding() async {
        profile = await profileManager.fetchProfile()
    }

    func completeOnboarding() async {
        profile = await profileManager.fetchProfile()
    }

    // MARK: - Apple Sign In

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)

        let coordinator = AppleSignInCoordinator { [weak self] result in
            Task { @MainActor in
                await self?.handleAppleSignIn(result: result)
            }
        }
        self.coordinator = coordinator

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.performRequests()

        isLoading = true
        errorMessage = nil
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        defer {
            isLoading = false
            coordinator = nil
        }

        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let idToken = String(data: identityTokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Failed to get Apple credentials."
                return
            }

            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController
                else {
                    errorMessage = "Unable to find root view controller."
                    return
                }

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Failed to get Google ID token."
                    return
                }

                let accessToken = result.user.accessToken.tokenString

                try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: accessToken
                    )
                )
            } catch let error as GIDSignInError where error.code == .canceled {
                // User cancelled — ignore
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Magic Link

    func sendMagicLink(email: String) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                try await supabase.auth.signInWithOTP(
                    email: email,
                    redirectTo: URL(string: "reef://auth-callback")
                )
                magicLinkEmail = email
                magicLinkSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                session = nil
                profile = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Nonce Utilities

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
