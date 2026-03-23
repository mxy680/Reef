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
            // Card — fixed height, no content changes
            VStack(spacing: 24) {
                // Pulsing icon
                ZStack {
                    Circle()
                        .fill(ReefColors.primary.opacity(isPulsing ? 0.15 : 0.1))
                        .frame(width: 90, height: 90)

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(ReefColors.primary)
                        .scaleEffect(isPulsing ? 1.08 : 1.0)
                }

                // Rotating message — fixed height container
                Text(messages[messageIndex])
                    .font(.epilogue(18, weight: .bold))
                    .tracking(-0.04 * 18)
                    .foregroundStyle(colors.text)
                    .multilineTextAlignment(.center)
                    .frame(height: 50)
                    .id(messageIndex)
                    .transition(.opacity)

                // Progress bar
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

                // Fun fact
                Text("Fun fact: this app was built instead of studying for midterms")
                    .font(.epilogue(12, weight: .semiBold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
                    .multilineTextAlignment(.center)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Pulse icon
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            isPulsing = true
        }

        // Progress bar — smooth linear fill
        withAnimation(.linear(duration: 4.0)) {
            progress = 1.0
        }

        // Rotate messages every 1s
        for i in 1..<messages.count {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(i) * 1.0))
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageIndex = i
                }
            }
        }

        // Auto-advance at 4.2s
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            onComplete()
        }
    }
}
