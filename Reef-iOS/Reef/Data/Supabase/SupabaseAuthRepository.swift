import Foundation
@preconcurrency import GoogleSignIn
import Supabase

struct SupabaseAuthRepository: AuthRepository {
    func authStateChanges() -> AsyncStream<AuthSession?> {
        AsyncStream { continuation in
            Task {
                for await (_, session) in supabase.auth.authStateChanges {
                    if let session {
                        let email = session.user.email
                        let name: String? = {
                            if let meta = session.user.userMetadata["display_name"],
                               case .string(let n) = meta {
                                return n
                            }
                            return nil
                        }()
                        continuation.yield(AuthSession(
                            userId: session.user.id.uuidString,
                            email: email,
                            displayName: name
                        ))
                    } else {
                        continuation.yield(nil)
                    }
                }
                continuation.finish()
            }
        }
    }

    func restoreSession() async throws -> AuthSession {
        let session = try await supabase.auth.session
        let name: String? = {
            if let meta = session.user.userMetadata["display_name"],
               case .string(let n) = meta {
                return n
            }
            return nil
        }()
        return AuthSession(
            userId: session.user.id.uuidString,
            email: session.user.email,
            displayName: name
        )
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }

    func sendMagicLink(email: String) async throws {
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "reef://auth-callback")
        )
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func handleURL(_ url: URL) async throws {
        // Google OAuth callback
        GIDSignIn.sharedInstance.handle(url)
        // Supabase magic link callback
        try await supabase.auth.session(from: url)
    }
}
