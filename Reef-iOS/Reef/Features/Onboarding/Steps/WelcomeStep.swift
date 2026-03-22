import SwiftUI

struct WelcomeStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let onContinue: () -> Void

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Card with horizontal split
                HStack(spacing: 0) {
                    // Left side — text content
                    VStack(alignment: .leading, spacing: 0) {
                        // Logo
                        Text("REEF")
                            .font(.epilogue(18, weight: .black))
                            .tracking(6)
                            .foregroundStyle(ReefColors.primary)
                            .fadeUp(index: 0)
                            .padding(.bottom, 20)

                        // Headline
                        Text("Your practice\nproblems\ntalk back")
                            .font(.epilogue(34, weight: .black))
                            .tracking(-0.04 * 34)
                            .foregroundStyle(colors.text)
                            .lineSpacing(2)
                            .fadeUp(index: 1)
                            .padding(.bottom, 14)

                        // Subline
                        Text("Stop switching apps. Stop waiting for office hours. Get real-time help the moment you need it.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(colors.textSecondary)
                            .lineSpacing(3)
                            .fadeUp(index: 2)
                            .padding(.bottom, 20)

                        // Social proof
                        HStack(spacing: 6) {
                            Text("🐠")
                                .font(.system(size: 13))
                            Text("Trusted by 10,000+ students")
                                .font(.epilogue(12, weight: .bold))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textSecondary)
                        }
                        .fadeUp(index: 3)
                        .padding(.bottom, 24)

                        // CTA
                        ReefButton("Let's go", action: onContinue)
                            .frame(maxWidth: 200)
                            .fadeUp(index: 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(28)

                    // Right side — app screenshot placeholder
                    // TODO: Replace with Image("onboarding-screenshot").resizable()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colors.subtle)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(colors.border, lineWidth: 1.5)
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(colors.textMuted)
                                Text("App screenshot")
                                    .font(.epilogue(12, weight: .medium))
                                    .tracking(-0.04 * 12)
                                    .foregroundStyle(colors.textMuted)
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .fadeUp(index: 2)
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
                .frame(maxWidth: metrics.onboardingCardMaxWidth + 100)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
