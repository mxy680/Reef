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

        VStack(spacing: 0) {
            Spacer()

            // Pulsing icon
            ZStack {
                Circle()
                    .fill(ReefColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)

                Circle()
                    .fill(ReefColors.primary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(ReefColors.primary)
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .padding(.bottom, 40)

            // Rotating message
            Text(messages[messageIndex])
                .font(.epilogue(20, weight: .bold))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)
                .id(messageIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.4), value: messageIndex)
                .padding(.bottom, 32)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colors.subtle)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [ReefColors.primary, ReefColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * progress))
                }
            }
            .frame(height: 10)
            .frame(maxWidth: 340)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .padding(.bottom, 32)

            // Social proof (appears midway)
            if progress > 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ReefColors.primary)
                    Text("92% of Reef students say they study less and learn more")
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(theme.colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.colors.border, lineWidth: 1.5)
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
