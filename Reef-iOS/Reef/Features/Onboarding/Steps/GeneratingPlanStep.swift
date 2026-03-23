import SwiftUI

struct GeneratingPlanStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var messageIndex = 0
    @State private var isPulsing = false

    private let messages = [
        "Crunching your courses...",
        "Finding your weak spots (respectfully)...",
        "Training your AI tutor...",
        "Brewing coffee... jk. Almost done.",
    ]

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Card
                VStack(spacing: 28) {
                    // Pulsing icon
                    ZStack {
                        Circle()
                            .fill(ReefColors.primary.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .scaleEffect(isPulsing ? 1.15 : 1.0)

                        Circle()
                            .fill(ReefColors.primary.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .scaleEffect(isPulsing ? 1.1 : 1.0)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(ReefColors.primary)
                    }
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)

                    // Rotating message
                    Text(messages[messageIndex])
                        .font(.epilogue(18, weight: .bold))
                        .tracking(-0.04 * 18)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .id(messageIndex)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.4), value: messageIndex)

                    // Progress bar (3D neobrutalist)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(colors.subtle)
                            .frame(height: 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(colors.border, lineWidth: 1.5)
                            )

                        GeometryReader { barGeo in
                            RoundedRectangle(cornerRadius: 7)
                                .fill(
                                    LinearGradient(
                                        colors: [ReefColors.primary, ReefColors.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(14, barGeo.size.width * progress))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(colors.border, lineWidth: 1.5)
                                )
                        }
                        .frame(height: 14)
                    }

                    // Social proof (appears midway)
                    if progress > 0.5 {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ReefColors.primary)
                            Text("92% of Reef students say they study less and learn more")
                                .font(.epilogue(12, weight: .semiBold))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ReefColors.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
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
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        isPulsing = true

        withAnimation(.easeInOut(duration: 4.0)) {
            progress = 1.0
        }

        for i in 1..<messages.count {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(i) * 1.0))
                withAnimation { messageIndex = i }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            onComplete()
        }
    }
}
