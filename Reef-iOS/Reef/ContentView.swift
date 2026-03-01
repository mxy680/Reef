import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading && authManager.session == nil {
                ZStack {
                    ReefColors.surface
                        .ignoresSafeArea()
                    ProgressView()
                }
            } else if authManager.isAuthenticated {
                LoggedInView()
            } else {
                AuthView()
            }
        }
    }
}
