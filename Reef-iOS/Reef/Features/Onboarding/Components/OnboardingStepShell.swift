import SwiftUI

struct OnboardingStepShell<Content: View>: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let title: String
    var subtitle: String? = nil
    let canAdvance: Bool
    var forwardLabel: String = "Continue"
    var showBack: Bool = true
    let onBack: (() -> Void)?
    let onForward: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: metrics.onboardingStepSpacing) {
                    // Title
                    Text(title)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    // Subtitle
                    if let subtitle {
                        Text(subtitle)
                            .font(.epilogue(15, weight: .medium))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(colors.textSecondary)
                            .fadeUp(index: 1)
                    }

                    // Content
                    content()
                        .fadeUp(index: 2)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth, alignment: .leading)
                .padding(.horizontal, metrics.authHPadding)
                .padding(.top, metrics.onboardingStepSpacing)
                .padding(.bottom, 100) // space for nav
            }

            // Navigation footer
            HStack {
                if showBack, let onBack {
                    ReefButton(.ghost, action: onBack) {
                        Text("Back")
                    }
                    .frame(maxWidth: 80)
                }

                Spacer()

                ReefButton(forwardLabel, disabled: !canAdvance, action: onForward)
                    .frame(maxWidth: 200)
            }
            .padding(.horizontal, metrics.authHPadding)
            .padding(.bottom, metrics.onboardingStepSpacing)
            .frame(maxWidth: metrics.onboardingCardMaxWidth)
        }
        .frame(maxWidth: .infinity)
    }
}
