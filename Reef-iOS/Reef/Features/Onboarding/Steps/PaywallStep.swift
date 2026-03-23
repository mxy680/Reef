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
                    VStack(spacing: 12) {
                        Text("🐠")
                            .font(.system(size: 36))

                        Text("Welcome to the beta")
                            .font(.epilogue(26, weight: .black))
                            .tracking(-0.04 * 26)
                            .foregroundStyle(ReefColors.white)

                        Text("Everything is free while we're in beta.\nJust use it. Tell us what's broken.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.white.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(ReefColors.primary)

                    // What you get
                    VStack(alignment: .leading, spacing: 14) {
                        Text("WHAT YOU GET")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(colors.textMuted)
                            .padding(.bottom, 4)

                        featureRow(icon: "infinity", text: "Unlimited tutoring hours")
                        featureRow(icon: "book.closed.fill", text: "All courses")
                        featureRow(icon: "mic.fill", text: "Voice chat with your tutor")
                        featureRow(icon: "chart.line.uptrend.xyaxis", text: "Study analytics")
                        featureRow(icon: "sparkles", text: "Early access to new features")
                    }
                    .padding(24)

                    // CTA
                    VStack(spacing: 12) {
                        ReefButton("Let's go — it's free", action: { viewModel.goNext() })

                        Text("Pricing comes later. You'll be the first to know.")
                            .font(.epilogue(11, weight: .medium))
                            .tracking(-0.04 * 11)
                            .foregroundStyle(colors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
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

    private func featureRow(icon: String, text: String) -> some View {
        let colors = theme.colors

        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ReefColors.primary)
                .frame(width: 24)

            Text(text)
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.text)
        }
    }
}
