import SwiftUI

/// Root view that routes between auth states.
/// Thin — no business logic, just state-based navigation.
struct AppRouter: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        Group {
            if auth.isLoading && auth.session == nil {
                loadingView
            } else if auth.isAuthenticated && auth.onboardingCompleted {
                // TODO: Replace with DashboardView when built
                placeholderDashboard
            } else if auth.isAuthenticated {
                // TODO: Replace with OnboardingView when built
                placeholderOnboarding
            } else {
                AuthView()
            }
        }
        .hoverEffectDisabled()
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()
            ProgressView()
        }
    }

    // MARK: - Placeholders (will be replaced as features are built)

    private var placeholderDashboard: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Dashboard")
                    .reefHeading()
                Text("Signed in as \(auth.displayName)")
                    .reefBody()
                ReefButton("Sign Out", variant: .secondary) {
                    Task { await auth.signOut() }
                }
                .frame(maxWidth: 200)
            }
        }
    }

    private var placeholderOnboarding: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Onboarding")
                    .reefHeading()
                Text("Complete your profile to continue")
                    .reefBody()
            }
        }
    }
}
