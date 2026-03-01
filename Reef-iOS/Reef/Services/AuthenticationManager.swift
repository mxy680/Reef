//
//  AuthenticationManager.swift
//  Reef
//
//  Supabase + Apple Sign-In authentication
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var userEmail: String?

    /// Raw nonce for the current Apple Sign-In request (kept in memory until completion)
    private var currentNonce: String?

    init() {
        listenForAuthChanges()
    }

    // MARK: - Auth State Listener

    private func listenForAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    if let session {
                        self.userEmail = session.user.email
                        self.isAuthenticated = true
                    }
                    self.isLoading = false
                case .signedIn:
                    if let session {
                        self.userEmail = session.user.email
                        self.isAuthenticated = true
                    }
                case .signedOut:
                    self.userEmail = nil
                    self.isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    /// Call from SignInWithAppleButton's `onRequest` to configure the nonce
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    /// Call from SignInWithAppleButton's `onCompletion`
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                return
            }

            Task {
                do {
                    let session = try await supabase.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken: idToken,
                            nonce: nonce
                        )
                    )

                    // Upsert display name on first sign-in (Apple only provides name once)
                    if let fullName = credential.fullName {
                        let givenName = fullName.givenName ?? ""
                        let familyName = fullName.familyName ?? ""
                        let displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                        if !displayName.isEmpty {
                            _ = try? await supabase.from("profiles")
                                .upsert([
                                    "id": session.user.id.uuidString,
                                    "display_name": displayName,
                                ])
                                .execute()
                        }
                    }
                } catch {
                    print("[Auth] Supabase signInWithIdToken failed: \(error)")
                }
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            print("[Auth] Apple Sign-In failed: \(error)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await supabase.auth.signOut()
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
