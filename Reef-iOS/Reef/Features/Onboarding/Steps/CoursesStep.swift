import SwiftUI

struct CoursesStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private var courseList: [String] {
        CourseCatalog.courses(for: viewModel.answers.studentType, major: viewModel.answers.major)
    }

    var body: some View {
        OnboardingStepShell(
            step: .courses,
            title: "What are you taking this semester?",
            subtitle: "Pick everything that's currently causing you stress. We can take it.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            OnboardingFlowLayout(spacing: 10) {
                ForEach(courseList, id: \.self) { course in
                    OnboardingPill(
                        label: course,
                        isSelected: viewModel.answers.courses.contains(course),
                        action: {
                            if viewModel.answers.courses.contains(course) {
                                viewModel.answers.courses.remove(course)
                            } else {
                                viewModel.answers.courses.insert(course)
                            }
                        }
                    )
                }

                OnboardingPill(
                    label: "+ Other",
                    isSelected: viewModel.answers.courses.contains("Other"),
                    action: {
                        if viewModel.answers.courses.contains("Other") {
                            viewModel.answers.courses.remove("Other")
                        } else {
                            viewModel.answers.courses.insert("Other")
                        }
                    }
                )
            }
        }
    }
}
