import SwiftUI

/// Root container for the onboarding quiz flow.
/// Renders the progress bar and switches between step views
/// with direction-aware slide transitions.
struct OnboardingFlowView: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @State private var viewModel: OnboardingViewModel

    init(profileRepo: ProfileRepository = SupabaseProfileRepository()) {
        let vm = OnboardingViewModel(profileRepo: profileRepo)
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        let colors = theme.colors

        ZStack {
            colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar (hidden on welcome)
                if viewModel.showProgressBar {
                    OnboardingProgressBar(progress: viewModel.progress)
                        .padding(.horizontal, metrics.authHPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }

                // Step content
                stepContent
                    .id(viewModel.currentStep)
                    .transition(slideTransition)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
        }
        .onAppear {
            viewModel.onComplete = {
                Task { await auth.completeOnboarding() }
            }
        }
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            // If user just signed in via SignUpStep, auto-advance past it
            if isAuth && viewModel.currentStep == .signUp {
                viewModel.goNext()
            }
        }
    }

    // MARK: - Slide Transition

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: viewModel.slideDirection > 0 ? .trailing : .leading),
            removal: .move(edge: viewModel.slideDirection > 0 ? .leading : .trailing)
        )
    }

    // MARK: - Step Router

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeStep(onContinue: { viewModel.goNext() })

        case .studentType:
            StudentTypeStep(viewModel: viewModel)

        case .major:
            MajorStep(viewModel: viewModel)

        case .courses:
            CoursesStep(viewModel: viewModel)

        case .favoriteTopic:
            FavoriteTopicStep(viewModel: viewModel)

        case .studyGoal:
            StudyGoalStep(viewModel: viewModel)

        case .goalValidation:
            GoalValidationStep(viewModel: viewModel)

        case .painPoints:
            PainPointsStep(viewModel: viewModel)

        case .learningStyle:
            LearningStyleStep(viewModel: viewModel)

        case .dailyGoal:
            DailyGoalStep(viewModel: viewModel)

        case .tutorDemo:
            TutorDemoStep(viewModel: viewModel)

        case .generatingPlan:
            GeneratingPlanStep(onComplete: { viewModel.goNext() })

        case .planPreview:
            PlanPreviewStep(viewModel: viewModel)

        case .signUp:
            SignUpStep(viewModel: viewModel)

        case .paywall:
            PaywallStep(viewModel: viewModel)

        case .referral:
            ReferralStep(viewModel: viewModel)
        }
    }
}
