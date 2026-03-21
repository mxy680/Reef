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

    // Teal-on-teal palette (white text on toolbar color)
    private let headerText = Color.white
    private let headerMuted = Color.white.opacity(0.55)
    private let headerSecondary = Color.white.opacity(0.7)
    private let dividerColor = Color.white.opacity(0.15)

    var body: some View {
        HStack(spacing: 0) {
            // Leading separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 0.5)

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 0) {
                    // === Top 1/3: Transcription ===
                    VStack(alignment: .leading, spacing: 0) {
                        transcriptionHeader

                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 0.5)

                        transcriptionContent
                    }
                    .frame(height: tutorModeOn ? geo.size.height / 3 : geo.size.height)

                    // === Bottom 2/3: Tutor Chat ===
                    if tutorModeOn {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)

                        tutorChatSection
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .background(
                ZStack {
                    (isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasDrawingBar.barColor)
                    Color.black.opacity(isDarkMode ? 0.15 : 0.05)
                }
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            transcriptionService.tickTimer()
        }
    }

    // MARK: - Transcription Header

    private var transcriptionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(headerSecondary)
            Text("Transcription")
                .font(.epilogue(13, weight: .black))
                .tracking(-0.04 * 13)
                .foregroundStyle(headerText)

            if let label = activeQuestionLabel {
                Text("·")
                    .font(.epilogue(13, weight: .black))
                    .foregroundStyle(headerMuted)
                Text(label)
                    .font(.epilogue(13, weight: .black))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(Color.white)
            }

            Spacer()

            if transcriptionService.sessionSecondsRemaining > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(transcriptionService.sessionSecondsRemaining > 60
                              ? Color(hex: 0x81C784) : Color(hex: 0xE57373))
                        .frame(width: 6, height: 6)
                    Text(timerLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(headerMuted)
                }
            }

            if transcriptionService.isTranscribing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Transcription Content

    @ViewBuilder
    private var transcriptionContent: some View {
        if !transcriptionService.latexResult.isEmpty {
            ScrollView {
                MathText(
                    text: transcriptionService.latexResult,
                    fontSize: 14,
                    color: .white
                )
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if transcriptionService.isTranscribing {
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Transcribing...")
                    .font(.epilogue(12, weight: .medium))
                    .foregroundStyle(headerMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = transcriptionService.errorMessage {
            Text(error)
                .font(.epilogue(12, weight: .medium))
                .foregroundStyle(Color(hex: 0xE57373))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 20))
                    .foregroundStyle(headerMuted)
                Text("Start writing")
                    .font(.epilogue(12, weight: .medium))
                    .foregroundStyle(headerMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tutor Chat Section

    private var tutorChatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chat header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(headerSecondary)
                Text("Tutor")
                    .font(.epilogue(13, weight: .black))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(headerText)

                Spacer()

                if tutorEvalService.isEvaluating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                            .tint(.white)
                        Text("thinking")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(headerMuted)
                    }
                } else {
                    Text("idle")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(headerMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 0.5)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if tutorEvalService.chatMessages.isEmpty {
                            VStack(spacing: 8) {
                                Text("Your work and feedback will appear here")
                                    .font(.epilogue(12, weight: .medium))
                                    .foregroundStyle(headerMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(tutorEvalService.chatMessages) { message in
                                chatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: tutorEvalService.chatMessages.count) { _, _ in
                    if let last = tutorEvalService.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chat Bubble

    private let shadowOffset: CGFloat = 3

    @ViewBuilder
    private func chatBubble(message: TutorChatMessage) -> some View {
        let isStudent = message.role == .student
        let bgColor: Color = isStudent ? .white : Color(hex: 0xFFF0F0)
        let borderColor = isStudent
            ? Color.black.opacity(0.8)
            : Color(hex: 0xE57373)
        let textColor: Color = isStudent ? .black : .black

        HStack {
            if isStudent { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isStudent ? "pencil.line" : "brain.head.profile")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isStudent ? "Your work" : "Feedback")
                        .font(.epilogue(10, weight: .bold))
                        .tracking(-0.04 * 10)
                }
                .foregroundStyle(isStudent ? Color.black.opacity(0.4) : Color(hex: 0xE57373))

                MathText(
                    text: message.latex,
                    fontSize: 13,
                    color: textColor
                )
            }
            .padding(10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(borderColor)
                        .offset(x: shadowOffset, y: shadowOffset)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bgColor)
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1.5)
                }
            )

            if !isStudent { Spacer(minLength: 20) }
        }
        .padding(.trailing, isStudent ? shadowOffset : 0)
        .padding(.bottom, shadowOffset)
    }
}
