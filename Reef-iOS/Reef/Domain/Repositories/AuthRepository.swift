import Foundation

/// Abstracts authentication providers (Supabase, etc.) behind a protocol
/// so the auth feature doesn't depend on any SDK directly.
protocol AuthRepository: Sendable {
    /// Listen for auth state changes. Returns an async stream of optional sessions.
    func authStateChanges() -> AsyncStream<AuthSession?>

    /// Attempt to restore a previously saved session.
    func restoreSession() async throws -> AuthSession

    /// Sign in with Apple ID token + nonce.
    func signInWithApple(idToken: String, nonce: String) async throws

    /// Sign in with Google ID token + access token.
    func signInWithGoogle(idToken: String, accessToken: String) async throws

    /// Send a magic link to the given email.
    func sendMagicLink(email: String) async throws

    /// Sign out the current user.
    func signOut() async throws

    /// Handle a deep link URL (magic link callback, Google OAuth).
    func handleURL(_ url: URL) async throws
}

/// Minimal session representation — decoupled from Supabase's Session type.
struct AuthSession: Sendable {
    let userId: String
    let email: String?
    let displayName: String?
}
