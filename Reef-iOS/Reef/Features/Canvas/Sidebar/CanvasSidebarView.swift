import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    var transcriptionService: HandwritingTranscriptionService

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 0) {
            // Leading separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 0.5)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.textSecondary)
                    Text("Transcription")
                        .font(.epilogue(13, weight: .black))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.text)
                    Spacer()
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
                ScrollView {
                    if !transcriptionService.latexResult.isEmpty {
                        MathText(
                            text: transcriptionService.latexResult,
                            fontSize: 15,
                            color: colors.text
                        )
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if transcriptionService.isTranscribing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(ReefColors.primary)
                            Text("Transcribing...")
                                .font(.epilogue(13, weight: .medium))
                                .foregroundStyle(colors.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else if let error = transcriptionService.errorMessage {
                        Text(error)
                            .font(.epilogue(13, weight: .medium))
                            .foregroundStyle(Color(hex: 0xE57373))
                            .padding(16)
                    } else {
                        Text("Start writing to see transcription")
                            .font(.epilogue(13, weight: .medium))
                            .foregroundStyle(colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
    }
}
