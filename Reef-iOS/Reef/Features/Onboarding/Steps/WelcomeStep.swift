import SwiftUI

struct WelcomeStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let onContinue: () -> Void

    var body: some View {
        let colors = theme.colors

        VStack(spacing: metrics.onboardingStepSpacing) {
            Spacer()

            // Logo
            Text("REEF")
                .font(.epilogue(40, weight: .black))
                .tracking(-0.04 * 40)
                .foregroundStyle(ReefColors.primary)
                .fadeUp(index: 0)

            // Headline
            Text("Your practice problems\ntalk back")
                .font(.epilogue(32, weight: .black))
                .tracking(-0.04 * 32)
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)
                .fadeUp(index: 1)

            // Subline
            Text("Stop switching apps. Stop waiting for office hours.\nGet real-time help the moment you need it.")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .fadeUp(index: 2)

            // Social proof
            Text("Trusted by 10,000+ students")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.02 * 13)
                .foregroundStyle(colors.textMuted)
                .fadeUp(index: 3)

            Spacer()

            // CTA
            ReefButton("Let's go", action: onContinue)
                .frame(maxWidth: 280)
                .fadeUp(index: 4)

            Spacer()
                .frame(height: metrics.onboardingStepSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
