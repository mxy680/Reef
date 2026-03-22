import SwiftUI

struct PlanPreviewStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 32)

                    // Ready badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ReefColors.primary)
                        Text("READY")
                            .font(.epilogue(12, weight: .black))
                            .tracking(2)
                            .foregroundStyle(ReefColors.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ReefColors.primary.opacity(0.12))
                    .clipShape(Capsule())
                    .fadeUp(index: 0)

                    Text("Your study plan\nis locked in.")
                        .font(.epilogue(32, weight: .black))
                        .tracking(-0.04 * 32)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 1)

                    // Plan card
                    VStack(spacing: 0) {
                        planRow(emoji: "📚", label: "Courses", value: viewModel.planCoursesLabel, isFirst: true)
                        planDivider()
                        planRow(emoji: "🎯", label: "Goal", value: viewModel.planGoalLabel, isFirst: false)
                        planDivider()
                        planRow(emoji: "⏰", label: "Daily commitment", value: viewModel.planDailyLabel, isFirst: false)
                        planDivider()
                        planRow(emoji: "🧠", label: "Tutor style", value: "Adaptive — visual, audio, hands-on, text", isFirst: false)
                        planDivider()
                        planRow(emoji: "💪", label: "Focus areas", value: viewModel.planFocusLabel, isFirst: false)
                    }
                    .background(colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colors.border, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.shadow)
                            .offset(x: 5, y: 5)
                    )
                    .fadeUp(index: 2)

                    ReefButton("Activate my plan", action: { viewModel.goNext() })
                        .fadeUp(index: 3)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func planRow(emoji: String, label: String, value: String, isFirst: Bool) -> some View {
        let colors = theme.colors
        return HStack(alignment: .top, spacing: 14) {
            // Emoji in a circle
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(ReefColors.primary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.epilogue(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(colors.textMuted)

                Text(value)
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(colors.text)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func planDivider() -> some View {
        Rectangle()
            .fill(theme.colors.divider)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}
