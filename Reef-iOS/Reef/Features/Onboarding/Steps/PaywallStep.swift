import SwiftUI

struct PaywallStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Card
                VStack(spacing: 0) {
                    // Header — beta hero
                    VStack(spacing: 14) {
                        Text("🐠")
                            .font(.system(size: 40))

                        Text("Welcome to the beta")
                            .font(.epilogue(28, weight: .black))
                            .tracking(-0.04 * 28)
                            .foregroundStyle(ReefColors.white)

                        Text("Everything is free while we're in beta.\nJust use it. Tell us what's broken.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.white.opacity(0.85))
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(ReefColors.primary)

                    // Features — styled cards
                    VStack(spacing: 10) {
                        featureCard(
                            icon: "infinity",
                            title: "Unlimited tutoring",
                            subtitle: "No hour limits. Study as much as you want."
                        )

                        featureCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Voice chat",
                            subtitle: "Talk to your tutor out loud."
                        )

                        featureCard(
                            icon: "pencil.tip.crop.circle",
                            title: "Handwriting recognition",
                            subtitle: "Just write. Reef reads it."
                        )

                        featureCard(
                            icon: "sparkles",
                            title: "Early access",
                            subtitle: "New features before anyone else."
                        )
                    }
                    .padding(20)

                    // CTA
                    VStack(spacing: 14) {
                        ReefButton("Let's go — it's free", action: { viewModel.goNext() })

                        Text("Pricing comes later. You'll be the first to know.")
                            .font(.epilogue(11, weight: .medium))
                            .tracking(-0.04 * 11)
                            .foregroundStyle(colors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
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

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        let colors = theme.colors

        return HStack(spacing: 14) {
            // Icon in tinted circle
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReefColors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ReefColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)

                Text(subtitle)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ReefColors.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.divider, lineWidth: 1)
        )
    }
}
