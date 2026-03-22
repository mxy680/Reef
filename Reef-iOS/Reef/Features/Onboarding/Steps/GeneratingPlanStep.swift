import SwiftUI

struct GeneratingPlanStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var messageIndex = 0

    private let messages = [
        "Crunching your courses...",
        "Finding your weak spots (respectfully)...",
        "Training your AI tutor...",
        "Brewing coffee... jk. Almost done.",
    ]

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 32) {
            Spacer()

            // Rotating message
            Text(messages[messageIndex])
                .font(.epilogue(18, weight: .bold))
                .tracking(-0.04 * 18)
                .foregroundStyle(colors.text)
                .id(messageIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: messageIndex)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.subtle)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ReefColors.primary)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            .frame(maxWidth: 300)

            // Social proof (appears midway)
            if progress > 0.5 {
                SocialProofBanner(text: "92% of Reef students say they study less and learn more")
                    .frame(maxWidth: 300)
                    .transition(.opacity)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Animate progress bar
        withAnimation(.easeInOut(duration: 4.0)) {
            progress = 1.0
        }

        // Rotate messages
        for i in 1..<messages.count {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(i) * 1.0))
                withAnimation { messageIndex = i }
            }
        }

        // Auto-advance after 4 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            onComplete()
        }
    }
}
