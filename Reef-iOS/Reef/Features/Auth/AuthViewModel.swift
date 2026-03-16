import AuthenticationServices
import CryptoKit
import Foundation
@preconcurrency import GoogleSignIn

/// Owns all auth state and orchestrates sign-in flows.
/// Depends on repository protocols — no direct Supabase imports.
@Observable
@MainActor
final class AuthViewModel {

    // MARK: - Published State

    var session: AuthSession?
    var profile: Profile?
    var isBootstrapping = true
    var isLoading = false
    var errorMessage: String?
    var magicLinkSent = false
    var magicLinkEmail = ""

    #if DEBUG
    var devMode = false
    #endif

    // MARK: - Computed

    var isAuthenticated: Bool {
        #if DEBUG
        if devMode { return true }
        #endif
        return session != nil
    }

    var onboardingCompleted: Bool {
        #if DEBUG
        if devMode { return true }
        #endif
        return profile?.onboardingCompleted == true
    }

    var displayName: String {
        if let name = session?.displayName, !name.isEmpty { return name }
        return session?.email?.components(separatedBy: "@").first ?? "User"
    }

    var userInitials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    // MARK: - Dependencies

    private let authRepo: AuthRepository
    private let profileRepo: ProfileRepository

    // MARK: - Private

    private var coordinator: AppleSignInCoordinator?
    private var currentNonce: String?
    private nonisolated(unsafe) var authListenerTask: Task<Void, Never>?

    // MARK: - Init

    init(authRepo: AuthRepository, profileRepo: ProfileRepository) {
        self.authRepo = authRepo
        self.profileRepo = profileRepo
        Task { await bootstrap() }
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        defer { isBootstrapping = false }

        #if DEBUG
        // UI tests: skip network calls, show auth screen immediately
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            session = nil
            return
        }
        #endif

        // 1. Try to restore saved session (primary path)
        do {
            session = try await authRepo.restoreSession()
            await refreshProfile()
        } catch {
            #if DEBUG
            devLogin()
            return
            #else
            session = nil
            #endif
        }

        // 2. Listen for ongoing auth changes (sign-in, sign-out, token refresh)
        authListenerTask = Task {
            for await authSession in authRepo.authStateChanges() {
                self.session = authSession
                if authSession != nil {
                    await refreshProfile()
                } else {
                    self.profile = nil
                }
            }
        }
    }

    // MARK: - Profile

    private func refreshProfile() async {
        do {
            profile = try await profileRepo.fetchProfile()
        } catch {
            // Profile fetch failure is non-fatal — don't block auth
        }
    }

    func completeOnboarding() async {
        do {
            profile = try await profileRepo.fetchProfile()
        } catch {
            // Non-fatal
        }
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
                try await authRepo.signInWithApple(idToken: idToken, nonce: nonce)
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
                try await authRepo.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            } catch let error as GIDSignInError where error.code == .canceled {
                // User cancelled — ignore
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Magic Link

    func sendMagicLink(email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard trimmed.contains("@"), trimmed.contains("."),
              trimmed.count >= 5, !trimmed.hasPrefix("@"), !trimmed.hasSuffix(".")
        else {
            errorMessage = "Please enter a valid email address."
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                try await authRepo.sendMagicLink(email: trimmed)
                magicLinkEmail = trimmed
                magicLinkSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await authRepo.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        devMode = false
        #endif
        session = nil
        profile = nil
    }

    // MARK: - URL Handling

    func handleURL(_ url: URL) {
        Task {
            do {
                try await authRepo.handleURL(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Dev Bypass

    #if DEBUG
    func devLogin() {
        devMode = true
        profile = Profile(
            id: "dev-user",
            displayName: "Dev User",
            email: "dev@example.com",
            subjects: [],
            onboardingCompleted: true
        )
    }
    #endif

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
