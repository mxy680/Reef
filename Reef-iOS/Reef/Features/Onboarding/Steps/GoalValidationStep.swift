import SwiftUI

struct GoalValidationStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Outer card wrapping everything
                VStack(spacing: 24) {
                    // Checkmark badge
                    ZStack {
                        Circle()
                            .fill(ReefColors.primary)
                            .frame(width: 56, height: 56)
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(ReefColors.white)
                    }
                    .background(
                        Circle()
                            .fill(colors.shadow)
                            .frame(width: 56, height: 56)
                            .offset(x: 3, y: 3)
                    )
                    .fadeUp(index: 0)

                    // Headline
                    Text(viewModel.goalValidationHeadline)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 1)

                    Text("You're not bad at this. You just don't have anyone watching your back. Now you do.")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 2)

                    // Feature cards row
                    HStack(spacing: 10) {
                        featureCard(icon: "eye.fill", text: "Sees your mistakes")
                        featureCard(icon: "bubble.left.fill", text: "Explains, doesn't judge")
                        featureCard(icon: "moon.stars.fill", text: "Available at 2am")
                    }
                    .fadeUp(index: 3)

                    // CTA
                    ReefButton("I'm in. Keep going", action: { viewModel.goNext() })
                        .fadeUp(index: 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(colors.border, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.shadow)
                        .offset(x: 5, y: 5)
                )
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func featureCard(icon: String, text: String) -> some View {
        let colors = theme.colors
        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ReefColors.primary)

            Text(text)
                .font(.epilogue(11, weight: .semiBold))
                .tracking(-0.04 * 11)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(ReefColors.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
