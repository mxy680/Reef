import SwiftUI

struct PaywallStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    @State private var selectedTier = 1  // 0=Shore, 1=Reef, 2=Abyss

    private var greeting: String {
        let name = auth.displayName
        if name.isEmpty || name == "User" {
            return "You're all set."
        }
        return "\(name), you're all set."
    }

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.onboardingStepSpacing) {
                    Text(greeting)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 0)

                    // Tier cards
                    VStack(spacing: 12) {
                        tierCard(
                            name: "Shore",
                            price: "Free",
                            tagline: "Dip your toes in.",
                            features: "1 course · 5 homeworks · 5 quizzes · 2 hrs tutoring",
                            tierIndex: 0,
                            badge: nil
                        )
                        .fadeUp(index: 1)

                        tierCard(
                            name: "Reef",
                            price: "$9.99/mo",
                            tagline: "The sweet spot.",
                            features: "5 courses · 50 homeworks · 50 quizzes · 20 hrs tutoring",
                            tierIndex: 1,
                            badge: "Most Popular"
                        )
                        .fadeUp(index: 2)

                        tierCard(
                            name: "Abyss",
                            price: "$29.99/mo",
                            tagline: "No limits. Ever.",
                            features: "Unlimited everything",
                            tierIndex: 2,
                            badge: nil
                        )
                        .fadeUp(index: 3)
                    }

                    ReefButton("Start your 14-day free trial", action: { viewModel.goNext() })
                        .fadeUp(index: 4)

                    ReefButton(.ghost, action: { viewModel.goNext() }) {
                        Text("Restore Purchases")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                    }
                    .fadeUp(index: 5)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func tierCard(
        name: String,
        price: String,
        tagline: String,
        features: String,
        tierIndex: Int,
        badge: String?
    ) -> some View {
        let colors = theme.colors
        let isSelected = selectedTier == tierIndex

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.epilogue(18, weight: .bold))
                    .tracking(-0.04 * 18)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)

                if let badge {
                    Text(badge)
                        .font(.epilogue(10, weight: .bold))
                        .tracking(-0.02 * 10)
                        .foregroundStyle(isSelected ? ReefColors.primary : ReefColors.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isSelected ? ReefColors.white : ReefColors.primary)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(price)
                    .font(.epilogue(16, weight: .bold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)
            }

            Text(tagline)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(isSelected ? ReefColors.white.opacity(0.8) : colors.textSecondary)

            Text(features)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(isSelected ? ReefColors.white.opacity(0.7) : colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isSelected ? ReefColors.primary : colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .reef3DPush(
            cornerRadius: 14,
            borderWidth: 2,
            borderColor: colors.border,
            shadowColor: colors.shadow,
            action: { selectedTier = tierIndex }
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
