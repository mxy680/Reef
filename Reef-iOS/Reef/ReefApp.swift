@preconcurrency import GoogleSignIn
import SwiftUI

@main
struct ReefApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    Task { try? await supabase.auth.session(from: url) }
                }
        }
    }
}
