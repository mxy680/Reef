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

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Card — contains title, subtitle, content, and navigation
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text(title)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .padding(.bottom, subtitle != nil ? 10 : 24)
                        .fadeUp(index: 0)

                    // Subtitle
                    if let subtitle {
                        Text(subtitle)
                            .font(.epilogue(15, weight: .medium))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(colors.textSecondary)
                            .padding(.bottom, 24)
                            .fadeUp(index: 1)
                    }

                    // Content
                    content()
                        .fadeUp(index: subtitle != nil ? 2 : 1)

                    // Navigation inside card
                    HStack(spacing: 16) {
                        if showBack, let onBack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(width: 48, height: 48)
                                    .background(colors.subtle)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(colors.border, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(NoHighlightButtonStyle())
                        }

                        ReefButton(forwardLabel, disabled: !canAdvance, action: onForward)
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                // Vertically center: ensure content is at least as tall as the viewport
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
