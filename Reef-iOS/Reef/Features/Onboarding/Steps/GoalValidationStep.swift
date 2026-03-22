import SwiftUI

struct GoalValidationStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 48)

                    // Checkmark badge
                    ZStack {
                        Circle()
                            .fill(ReefColors.primary)
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ReefColors.white)
                    }
                    .background(
                        Circle()
                            .fill(colors.shadow)
                            .frame(width: 64, height: 64)
                            .offset(x: 4, y: 4)
                    )
                    .fadeUp(index: 0)

                    // Main headline card
                    VStack(spacing: 16) {
                        Text(viewModel.goalValidationHeadline)
                            .font(.epilogue(28, weight: .black))
                            .tracking(-0.04 * 28)
                            .foregroundStyle(ReefColors.white)
                            .multilineTextAlignment(.center)

                        Text("Real talk — most students struggle because they're studying alone with zero feedback.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(ReefColors.primary)
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
                    .fadeUp(index: 1)

                    // Feature cards row
                    HStack(spacing: 12) {
                        featureCard(
                            icon: "eye.fill",
                            text: "Watches your work in real time"
                        )
                        featureCard(
                            icon: "bubble.left.fill",
                            text: "Jumps in before you spiral"
                        )
                        featureCard(
                            icon: "brain.head.profile.fill",
                            text: "Like a TA who actually shows up"
                        )
                    }
                    .fadeUp(index: 2)

                    // CTA
                    ReefButton("I'm in. Keep going", action: { viewModel.goNext() })
                        .frame(maxWidth: 300)
                        .fadeUp(index: 3)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func featureCard(icon: String, text: String) -> some View {
        let colors = theme.colors
        return VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ReefColors.primary)

            Text(text)
                .font(.epilogue(12, weight: .semiBold))
                .tracking(-0.04 * 12)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.border, lineWidth: 1.5)
        )
    }
}
