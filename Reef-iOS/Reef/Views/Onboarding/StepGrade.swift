import SwiftUI

private let grades: [(value: String, label: String)] = [
    ("middle_school", "Middle School"),
    ("high_school", "High School"),
    ("college", "College"),
    ("graduate", "Graduate"),
    ("other", "Other"),
]

struct StepGrade: View {
    @Binding var grade: String
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What grade are you in?")
                .reefHeading()
                .padding(.bottom, 6)
                .fadeUp(index: 0)

            Text("This helps us tailor content to your level.")
                .reefBody()
                .padding(.bottom, 24)
                .fadeUp(index: 1)

            VStack(spacing: 10) {
                ForEach(grades, id: \.value) { item in
                    OnboardingOptionButton(
                        label: item.label,
                        isSelected: grade == item.value
                    ) {
                        grade = item.value
                    }
                }
            }
            .padding(.bottom, 24)
            .fadeUp(index: 2)

            OnboardingNavigation(
                backLabel: "Back",
                forwardLabel: "Continue",
                canAdvance: !grade.isEmpty,
                onBack: onBack,
                onForward: onNext
            )
            .fadeUp(index: 3)
        }
    }
}
