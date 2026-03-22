import SwiftUI

struct WelcomeStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let onContinue: () -> Void

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            Spacer()

            // Hero icon composition
            ZStack {
                // Background circle
                Circle()
                    .fill(ReefColors.primary.opacity(0.1))
                    .frame(width: 140, height: 140)

                // Main icon
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(ReefColors.primary)

                // Pencil accent
                Image(systemName: "pencil.tip")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(colors.text)
                    .offset(x: 50, y: -40)
            }
            .fadeUp(index: 0)
            .padding(.bottom, 32)

            // Logo
            Text("REEF")
                .font(.epilogue(20, weight: .black))
                .tracking(8)
                .foregroundStyle(ReefColors.primary)
                .fadeUp(index: 1)
                .padding(.bottom, 16)

            // Headline
            Text("Your practice problems\ntalk back")
                .font(.epilogue(38, weight: .black))
                .tracking(-0.04 * 38)
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)
                .fadeUp(index: 2)
                .padding(.bottom, 16)

            // Subline
            Text("Stop switching apps. Stop waiting for office hours.\nGet real-time help the moment you need it.")
                .font(.epilogue(16, weight: .medium))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .fadeUp(index: 3)
                .padding(.bottom, 24)

            // Social proof badge
            HStack(spacing: 6) {
                Text("🐠")
                    .font(.system(size: 14))
                Text("Trusted by 10,000+ students")
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(colors.card)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                Capsule()
                    .fill(colors.shadow)
                    .offset(x: 3, y: 3)
            )
            .fadeUp(index: 4)

            Spacer()

            // CTA
            ReefButton("Let's go", action: onContinue)
                .frame(maxWidth: 320)
                .padding(.horizontal, metrics.authHPadding)
                .fadeUp(index: 5)

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
