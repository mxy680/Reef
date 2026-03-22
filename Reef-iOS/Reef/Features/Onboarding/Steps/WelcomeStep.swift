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
                        Text("hey, come in")
                            .font(.epilogue(16, weight: .bold))
                            .tracking(-0.04 * 16)
                            .foregroundStyle(ReefColors.primary)
                            .fadeUp(index: 0)
                            .padding(.bottom, 12)

                        // Headline
                        Text("Your TA\nis ready")
                            .font(.epilogue(34, weight: .black))
                            .tracking(-0.04 * 34)
                            .foregroundStyle(colors.text)
                            .lineSpacing(2)
                            .fadeUp(index: 1)
                            .padding(.bottom, 14)

                        // Subline
                        Text("Reads your handwriting. Talks you through it. Never cancels.")
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
                            Text("10,000+ students already in")
                                .font(.epilogue(12, weight: .bold))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textSecondary)
                        }
                        .fadeUp(index: 3)
                        .padding(.bottom, 24)

                        // CTA
                        ReefButton("Dive in", action: onContinue)
                            .frame(maxWidth: 200)
                            .fadeUp(index: 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(28)

                    // Right side — visual block
                    VStack(spacing: 14) {
                        // Feature cards stacked with slight overlap
                        featureCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            label: "Voice tutor",
                            description: "Talks through problems out loud",
                            color: ReefColors.primary
                        )
                        .fadeUp(index: 1)
                        .rotationEffect(.degrees(-2))

                        featureCard(
                            icon: "pencil.tip.crop.circle",
                            label: "Reads your writing",
                            description: "No typing. Just write.",
                            color: Color(hex: 0xEB8C73)
                        )
                        .fadeUp(index: 2)
                        .rotationEffect(.degrees(1.5))

                        featureCard(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Knows when you're stuck",
                            description: "Jumps in before you spiral",
                            color: ReefColors.accent
                        )
                        .fadeUp(index: 3)
                        .rotationEffect(.degrees(-1))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.trailing, 28)
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

    private func featureCard(
        icon: String,
        label: String,
        description: String,
        color: Color
    ) -> some View {
        let colors = theme.colors

        return HStack(spacing: 14) {
            // Icon circle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ReefColors.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)

                Text(description)
                    .font(.epilogue(11, weight: .medium))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colors.border, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colors.shadow)
                .offset(x: 3, y: 3)
        )
    }
}
