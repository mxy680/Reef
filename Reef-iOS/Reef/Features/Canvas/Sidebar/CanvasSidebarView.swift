import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    var transcriptionService: HandwritingTranscriptionService
    var activeQuestionLabel: String?

    private var timerLabel: String {
        let r = transcriptionService.sessionSecondsRemaining
        guard r > 0 else { return "" }
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 0) {
            // Leading separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 0.5)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.textSecondary)
                    Text("Transcription")
                        .font(.epilogue(13, weight: .black))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.text)

                    if let label = activeQuestionLabel {
                        Text("·")
                            .font(.epilogue(13, weight: .black))
                            .foregroundStyle(colors.textMuted)
                        Text(label)
                            .font(.epilogue(13, weight: .black))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(ReefColors.primary)
                    }

                    Spacer()

                    // Session timer
                    if transcriptionService.sessionSecondsRemaining > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(transcriptionService.sessionSecondsRemaining > 60
                                      ? Color(hex: 0x81C784) : Color(hex: 0xE57373))
                                .frame(width: 6, height: 6)
                            Text(timerLabel)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(colors.textMuted)
                        }
                    }

                    if transcriptionService.isTranscribing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .tint(ReefColors.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Separator
                Rectangle()
                    .fill(colors.divider)
                    .frame(height: 0.5)

                // Content
                if !transcriptionService.latexResult.isEmpty {
                    ScrollView {
                        MathText(
                            text: transcriptionService.latexResult,
                            fontSize: 15,
                            color: colors.text
                        )
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if transcriptionService.isTranscribing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(ReefColors.primary)
                        Text("Transcribing...")
                            .font(.epilogue(13, weight: .medium))
                            .foregroundStyle(colors.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = transcriptionService.errorMessage {
                    Text(error)
                        .font(.epilogue(13, weight: .medium))
                        .foregroundStyle(Color(hex: 0xE57373))
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 24))
                            .foregroundStyle(colors.textMuted)
                        Text("Start writing to see transcription")
                            .font(.epilogue(13, weight: .medium))
                            .foregroundStyle(colors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            transcriptionService.tickTimer()
        }
    }
}
