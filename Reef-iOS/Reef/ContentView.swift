import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var theme
    @State private var canvasDocument: Document?

    var body: some View {
        Group {
            if canvasDocument != nil {
                DocumentCanvasView(document: canvasDocument!) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        canvasDocument = nil
                    }
                }
                .transition(.opacity)
            } else if authManager.isLoading && authManager.session == nil {
                ZStack {
                    (theme.isDarkMode ? ReefColors.DashboardDark.background : ReefColors.surface)
                        .ignoresSafeArea()
                    ProgressView()
                }
            } else if authManager.isAuthenticated && authManager.onboardingCompleted {
                LoggedInView(onOpenCanvas: { doc in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        canvasDocument = doc
                    }
                })
            } else if authManager.isAuthenticated {
                OnboardingView()
            } else {
                AuthView()
            }
        }
        .hoverEffectDisabled()
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if authManager.devMode && canvasDocument == nil {
                Button {
                    canvasDocument = Document(
                        id: "dev-test",
                        userId: "dev",
                        filename: "Test Canvas.pdf",
                        status: .completed,
                        pageCount: 1,
                        problemCount: 1,
                        questionPages: [[0, 0]],
                        questionRegions: nil,
                        errorMessage: nil,
                        statusMessage: nil,
                        costCents: nil,
                        courseId: nil,
                        createdAt: "2026-01-01T00:00:00Z"
                    )
                } label: {
                    Text("Test Canvas")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
            }
        }
        #endif
    }
}
