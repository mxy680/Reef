import SwiftUI

private let sources: [(value: String, label: String)] = [
    ("social_media", "Social Media"),
    ("friend_family", "Friend or Family"),
    ("teacher_school", "Teacher or School"),
    ("google", "Google Search"),
    ("youtube", "YouTube"),
    ("other", "Other"),
]

struct StepReferral: View {
    @Binding var referralSource: String
    let onSubmit: () -> Void
    let onBack: () -> Void
    let submitting: Bool
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How did you hear about us?")
                .reefHeading()
                .padding(.bottom, 6)
                .fadeUp(index: 0)

            Text("This helps us understand how students find Reef.")
                .reefBody()
                .padding(.bottom, 24)
                .fadeUp(index: 1)

            VStack(spacing: 10) {
                ForEach(sources, id: \.value) { source in
                    OnboardingOptionButton(
                        label: source.label,
                        isSelected: referralSource == source.value
                    ) {
                        referralSource = source.value
                    }
                }
            }
            .padding(.bottom, 24)
            .fadeUp(index: 2)

            if let error {
                Text(error)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.error)
                    .padding(.bottom, 12)
            }

            OnboardingNavigation(
                backLabel: "Back",
                forwardLabel: "Get Started",
                canAdvance: !referralSource.isEmpty,
                isSubmitting: submitting,
                onBack: onBack,
                onForward: onSubmit
            )
            .fadeUp(index: 3)
        }
    }
}
