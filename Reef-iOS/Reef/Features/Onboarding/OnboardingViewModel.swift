import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - State

    var answers = OnboardingAnswers()
    var currentStep: OnboardingStep = .welcome
    var slideDirection: CGFloat = 1  // 1 = forward, -1 = back
    var isSubmitting = false
    var error: String?
    var showLearningStyleReassurance = false

    // MARK: - Dependencies

    private let profileRepo: ProfileRepository

    init(profileRepo: ProfileRepository) {
        self.profileRepo = profileRepo
    }

    // MARK: - Computed Steps (branching)

    var steps: [OnboardingStep] {
        var result: [OnboardingStep] = [.welcome, .studentType]

        // College/grad get the major screen
        if answers.studentType == .college || answers.studentType == .graduate {
            result.append(.major)
        }

        result.append(contentsOf: [
            .courses,
            .favoriteTopic,
            .studyGoal,
            .goalValidation,
            .painPoints,
            .learningStyle,
            .dailyGoal,
            .tutorDemo,
            .generatingPlan,
            .planPreview,
            .signUp,
            .paywall,
            .referral,
        ])

        return result
    }

    var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var progress: CGFloat {
        guard steps.count > 1 else { return 0 }
        return CGFloat(currentStepIndex) / CGFloat(steps.count - 1)
    }

    var showProgressBar: Bool {
        currentStep != .welcome
    }

    // MARK: - Validation

    var canAdvance: Bool {
        switch currentStep {
        case .welcome, .goalValidation, .generatingPlan, .planPreview, .paywall:
            return true
        case .studentType:
            return answers.studentType != nil
        case .major:
            return answers.major != nil
        case .courses:
            return !answers.courses.isEmpty
        case .favoriteTopic:
            return !answers.favoriteTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .studyGoal:
            return answers.studyGoal != nil
        case .painPoints:
            return !answers.painPoints.isEmpty
        case .learningStyle:
            return answers.learningStyle != nil
        case .dailyGoal:
            return answers.dailyGoal != nil
        case .tutorDemo:
            return true
        case .signUp:
            return true  // can skip
        case .referral:
            return answers.referralSource != nil
        }
    }

    // MARK: - Navigation

    func goNext() {
        guard let idx = steps.firstIndex(of: currentStep),
              idx + 1 < steps.count else { return }
        slideDirection = 1
        showLearningStyleReassurance = false
        currentStep = steps[idx + 1]
    }

    func goBack() {
        guard let idx = steps.firstIndex(of: currentStep),
              idx > 0 else { return }
        slideDirection = -1
        showLearningStyleReassurance = false
        currentStep = steps[idx - 1]
    }

    // MARK: - Goal Validation Copy

    var goalValidationHeadline: String {
        let courseList = Array(answers.courses).filter { $0 != "Other" }
        switch courseList.count {
        case 0:
            return "Yeah, we got you."
        case 1:
            return "\(courseList[0])? Yeah, we got you."
        case 2:
            return "\(courseList[0]) and \(courseList[1])? Yeah, we got you."
        default:
            return "\(courseList[0]), \(courseList[1]), and the rest? Yeah, we got you."
        }
    }

    // MARK: - Plan Preview Data

    var planGoalLabel: String {
        answers.studyGoal?.displayLabel ?? "Ace my exams"
    }

    var planCoursesLabel: String {
        let list = Array(answers.courses).sorted()
        guard !list.isEmpty else { return "Your courses" }
        return list.joined(separator: ", ")
    }

    var planDailyLabel: String {
        guard let goal = answers.dailyGoal else { return "30 min/day" }
        let minutes = goal.rawValue
        if minutes >= 60 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour/day" : "\(hours)+ hours/day"
        }
        return "\(minutes) min/day"
    }

    var planStyleLabel: String {
        answers.learningStyle?.displayLabel ?? "Whatever works for you"
    }

    var planFocusLabel: String {
        let labels = answers.painPoints.map(\.displayLabel)
        guard !labels.isEmpty else { return "General improvement" }
        return labels.joined(separator: ", ")
    }

    // MARK: - Submit

    func submitOnboarding() async {
        isSubmitting = true
        error = nil

        let update = ProfileUpdate(
            grade: answers.studentType?.rawValue,
            subjects: Array(answers.courses),
            referralSource: answers.referralSource?.rawValue,
            major: answers.major?.rawValue,
            studyGoal: answers.studyGoal?.rawValue,
            painPoints: answers.painPoints.map(\.rawValue),
            learningStyle: answers.learningStyle?.rawValue,
            favoriteTopic: answers.favoriteTopic,
            onboardingCompleted: true,
            settings: {
                var s = UserSettings()
                s.dailyGoalMinutes = answers.dailyGoal?.rawValue ?? 30
                return s
            }()
        )

        do {
            try await profileRepo.upsertProfile(update)
            onComplete?()
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }

    /// Called after successful submit to trigger auth refresh.
    var onComplete: (() -> Void)?
}
