import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var canvasDocument: Document?

    var body: some View {
        Group {
            if canvasDocument != nil {
                DocumentCanvasView(document: canvasDocument!) {
                    canvasDocument = nil
                }
            } else if authManager.isLoading && authManager.session == nil {
                ZStack {
                    ReefColors.surface
                        .ignoresSafeArea()
                    ProgressView()
                }
            } else if authManager.isAuthenticated && authManager.onboardingCompleted {
                LoggedInView(onOpenCanvas: { doc in
                    canvasDocument = doc
                })
            } else if authManager.isAuthenticated {
                OnboardingView()
            } else {
                AuthView()
            }
        }
        .hoverEffectDisabled()
    }
}
