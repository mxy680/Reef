import Supabase
import SwiftUI

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var step = 0
    @State private var direction: CGFloat = 1
    @State private var submitting = false
    @State private var error: String?

    // Form data
    @State private var name = ""
    @State private var grade = ""
    @State private var subjects: [String] = []
    @State private var referralSource = ""

    private let profileManager = ProfileManager()

    var body: some View {
        ZStack {
            ReefColors.surface
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)

                        ReefCard {
                            VStack(spacing: 0) {
                                OnboardingProgressDots(current: step, total: 4)

                                Group {
                                    switch step {
                                    case 0:
                                        StepName(name: $name, onNext: goNext)
                                            .transition(slideTransition)
                                    case 1:
                                        StepGrade(grade: $grade, onNext: goNext, onBack: goBack)
                                            .transition(slideTransition)
                                    case 2:
                                        StepSubjects(subjects: $subjects, onNext: goNext, onBack: goBack)
                                            .transition(slideTransition)
                                    case 3:
                                        StepReferral(
                                            referralSource: $referralSource,
                                            onSubmit: handleSubmit,
                                            onBack: goBack,
                                            submitting: submitting,
                                            error: error
                                        )
                                        .transition(slideTransition)
                                    default:
                                        EmptyView()
                                    }
                                }
                                .animation(.easeInOut(duration: 0.25), value: step)
                            }
                        }
                        .frame(maxWidth: 480)

                        Spacer(minLength: 60)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    .padding(.horizontal, 24)
                }
            }
        }
        .task {
            await resumeFromPartialProfile()
        }
    }

    // MARK: - Navigation

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: direction > 0 ? 80 : -80).combined(with: .opacity),
            removal: .offset(x: direction > 0 ? -80 : 80).combined(with: .opacity)
        )
    }

    private func goNext() {
        direction = 1
        withAnimation(.easeInOut(duration: 0.25)) {
            step += 1
        }
        savePartialProgress(nextStep: step)
    }

    private func goBack() {
        direction = -1
        withAnimation(.easeInOut(duration: 0.25)) {
            step -= 1
        }
    }

    // MARK: - Persistence

    private func resumeFromPartialProfile() async {
        guard let profile = authManager.profile else { return }
        name = profile.displayName ?? ""
        grade = profile.grade ?? ""
        subjects = profile.subjects
        referralSource = profile.referralSource ?? ""

        // Resume from the first incomplete step
        if name.isEmpty { step = 0 }
        else if grade.isEmpty { step = 1 }
        else if subjects.isEmpty { step = 2 }
        else { step = 3 }
    }

    private func savePartialProgress(nextStep: Int) {
        Task {
            var fields: [String: AnyJSON] = [
                "onboarding_completed": .bool(false),
            ]
            if let email = authManager.session?.user.email {
                fields["email"] = .string(email)
            }
            if nextStep > 0 { fields["display_name"] = .string(name.trimmingCharacters(in: .whitespaces)) }
            if nextStep > 1 { fields["grade"] = .string(grade) }
            if nextStep > 2 { fields["subjects"] = .array(subjects.map { .string($0) }) }
            try? await profileManager.upsertProfile(fields: fields)
        }
    }

    private func handleSubmit() {
        submitting = true
        error = nil

        Task {
            do {
                var fields: [String: AnyJSON] = [
                    "display_name": .string(name.trimmingCharacters(in: .whitespaces)),
                    "grade": .string(grade),
                    "subjects": .array(subjects.map { .string($0) }),
                    "referral_source": .string(referralSource),
                    "onboarding_completed": .bool(true),
                ]
                if let email = authManager.session?.user.email {
                    fields["email"] = .string(email)
                }
                try await profileManager.upsertProfile(fields: fields)
                await authManager.completeOnboarding()
            } catch {
                self.error = "Something went wrong saving your profile. Please try again."
                submitting = false
            }
        }
    }
}
