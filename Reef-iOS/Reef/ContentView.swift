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
        #if DEBUG
        .onAppear {
            if authManager.devMode && canvasDocument == nil {
                canvasDocument = Document(
                    id: "dev-test",
                    userId: "dev",
                    filename: "Test Canvas.pdf",
                    status: .completed,
                    pageCount: 1,
                    problemCount: nil,
                    errorMessage: nil,
                    statusMessage: nil,
                    costCents: nil,
                    courseId: nil,
                    createdAt: "2026-01-01T00:00:00Z"
                )
            }
        }
        #endif
    }
}
