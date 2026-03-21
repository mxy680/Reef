import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    var transcriptionService: HandwritingTranscriptionService
    var tutorEvalService: TutorEvaluationService
    var tutorModeOn: Bool
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

                // Top half: Transcription content
                transcriptionContent(colors: colors)

                // Bottom half: Tutor feedback (only when tutor mode is on)
                if tutorModeOn {
                    // Separator
                    Rectangle()
                        .fill(colors.divider)
                        .frame(height: 0.5)

                    tutorFeedbackSection(colors: colors)
                }
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            transcriptionService.tickTimer()
        }
    }

    // MARK: - Transcription Content

    @ViewBuilder
    private func transcriptionContent(colors: ReefThemeColors) -> some View {
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

    // MARK: - Tutor Feedback Section

    @ViewBuilder
    private func tutorFeedbackSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.textSecondary)
                Text("Tutor")
                    .font(.epilogue(13, weight: .black))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)

                Spacer()

                if tutorEvalService.isEvaluating {
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

            // Feedback content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let mistake = tutorEvalService.mistakeExplanation {
                        // Mistake card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xE57373))
                                Text("Needs attention")
                                    .font(.epilogue(12, weight: .bold))
                                    .tracking(-0.04 * 12)
                                    .foregroundStyle(Color(hex: 0xE57373))
                            }

                            MathText(
                                text: mistake,
                                fontSize: 14,
                                color: colors.text
                            )
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: 0xE57373).opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: 0xE57373).opacity(0.3), lineWidth: 1)
                        )
                    } else if tutorEvalService.status == "working" {
                        // On track indicator
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x81C784))
                            Text("On track")
                                .font(.epilogue(13, weight: .medium))
                                .foregroundStyle(Color(hex: 0x81C784))
                        }
                        .padding(12)
                    } else if tutorEvalService.status == "completed" {
                        // Step complete
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x81C784))
                            Text("Step complete!")
                                .font(.epilogue(13, weight: .bold))
                                .foregroundStyle(Color(hex: 0x81C784))
                        }
                        .padding(12)
                    } else {
                        // Idle / waiting
                        Text("Write your work to get feedback")
                            .font(.epilogue(13, weight: .medium))
                            .foregroundStyle(colors.textMuted)
                            .padding(12)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: tutorEvalService.status)
        .animation(.easeInOut(duration: 0.2), value: tutorEvalService.mistakeExplanation)
    }
}
