import SwiftUI

// MARK: - Screen Enum

private enum AppScreen: Equatable {
    case loading
    case auth
    case onboarding
    case dashboard
}

/// Root view that routes between auth states.
/// Thin — no business logic, just state-based navigation.
struct AppRouter: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ReefTheme.self) private var theme

    private var currentScreen: AppScreen {
        if auth.isBootstrapping {
            return .loading
        } else if auth.isAuthenticated && auth.onboardingCompleted {
            return .dashboard
        } else if auth.isAuthenticated {
            return .onboarding
        } else {
            return .auth
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch currentScreen {
                case .loading:
                    splashView
                        .transition(.opacity)
                        .accessibilityIdentifier("screen.loading")

                case .auth:
                    AuthView()
                        .transition(.opacity)
                        .accessibilityIdentifier("screen.auth")

                case .onboarding:
                    OnboardingFlowView()
                        .transition(.opacity)
                        .accessibilityIdentifier("screen.onboarding")

                case .dashboard:
                    DashboardView()
                        .transition(.opacity)
                        .accessibilityIdentifier("screen.dashboard")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.reefLayoutMetrics, ReefLayoutMetrics(screenHeight: shortSide))
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                if currentScreen == .dashboard {
                    Button(action: restartOnboarding) {
                        Label("Restart Onboarding", systemImage: "arrow.counterclockwise")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(-0.04 * 11)
                            .foregroundStyle(ReefColors.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ReefColors.destructive.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(NoHighlightButtonStyle())
                    .padding(.top, 4)
                    .padding(.trailing, 8)
                }
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.35), value: currentScreen)
        .hoverEffectDisabled()
    }

    // MARK: - Debug

    #if DEBUG
    private func restartOnboarding() {
        let repo = SupabaseProfileRepository()
        Task {
            try? await repo.upsertProfile(ProfileUpdate(onboardingCompleted: false))
            await auth.completeOnboarding() // refreshes profile → router shows onboarding
        }
    }
    #endif

    // MARK: - Splash / Loading

    private var splashView: some View {
        ZStack {
            theme.colors.surface
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("REEF")
                    .font(.epilogue(40, weight: .black))
                    .tracking(-0.04 * 40)
                    .foregroundStyle(ReefColors.primary)

                ProgressView()
                    .tint(ReefColors.primary)
            }
        }
    }

}
