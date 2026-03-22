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
                VStack(alignment: .leading, spacing: 0) {
                    // Top spacing
                    Spacer()
                        .frame(height: 40)

                    // Title
                    Text(title)
                        .font(.epilogue(32, weight: .black))
                        .tracking(-0.04 * 32)
                        .foregroundStyle(colors.text)
                        .padding(.bottom, subtitle != nil ? 12 : 28)
                        .fadeUp(index: 0)

                    // Subtitle
                    if let subtitle {
                        Text(subtitle)
                            .font(.epilogue(16, weight: .medium))
                            .tracking(-0.04 * 16)
                            .foregroundStyle(colors.textSecondary)
                            .padding(.bottom, 28)
                            .fadeUp(index: 1)
                    }

                    // Content
                    content()
                        .fadeUp(index: subtitle != nil ? 2 : 1)
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth, alignment: .leading)
                .padding(.horizontal, metrics.authHPadding)
                .padding(.bottom, 120)
            }

            // Navigation footer
            VStack(spacing: 0) {
                // Divider
                Rectangle()
                    .fill(colors.divider)
                    .frame(height: 1)

                HStack(spacing: 16) {
                    if showBack, let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(colors.textSecondary)
                                .frame(width: 48, height: 48)
                                .background(colors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colors.border, lineWidth: 2)
                                )
                        }
                        .buttonStyle(NoHighlightButtonStyle())
                    }

                    ReefButton(forwardLabel, disabled: !canAdvance, action: onForward)
                }
                .padding(.horizontal, metrics.authHPadding)
                .padding(.vertical, 16)
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
            }
            .background(colors.background.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
    }
}
