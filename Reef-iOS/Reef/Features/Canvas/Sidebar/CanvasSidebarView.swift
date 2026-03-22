import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    var transcriptionService: HandwritingTranscriptionService
    var tutorEvalService: TutorEvaluationService
    var tutorModeOn: Bool
    var activeQuestionLabel: String?
    var onSendChat: ((String) -> Void)?

    @State private var chatInput: String = ""

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 0) {
            // Leading separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 0.5)

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 0) {
                    // === Top 1/3: Transcription ===
                    VStack(alignment: .leading, spacing: 0) {
                        transcriptionHeader(colors: colors)

                        Rectangle()
                            .fill(colors.divider)
                            .frame(height: 0.5)

                        transcriptionContent(colors: colors)
                    }
                    .frame(height: tutorModeOn ? geo.size.height / 3 : geo.size.height)

                    // === Bottom 2/3: Tutor Chat ===
                    if tutorModeOn {
                        Rectangle()
                            .fill(colors.divider)
                            .frame(height: 1)

                        tutorChatSection(colors: colors)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            transcriptionService.tickTimer()
        }
    }

    // MARK: - Transcription Header

    @ViewBuilder
    private func transcriptionHeader(colors: ReefThemeColors) -> some View {
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

            if transcriptionService.isTranscribing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(ReefColors.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Transcription Content

    @ViewBuilder
    private func transcriptionContent(colors: ReefThemeColors) -> some View {
        if !transcriptionService.latexResult.isEmpty {
            ScrollView {
                MathText(
                    text: transcriptionService.latexResult,
                    fontSize: 14,
                    color: colors.text
                )
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if transcriptionService.isTranscribing {
            VStack(spacing: 8) {
                ProgressView()
                    .tint(ReefColors.primary)
                Text("Transcribing...")
                    .font(.epilogue(12, weight: .medium))
                    .foregroundStyle(colors.textMuted)
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
                    .foregroundStyle(colors.textMuted)
                Text("Start writing")
                    .font(.epilogue(12, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tutor Chat Section

    @ViewBuilder
    private func tutorChatSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chat header
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
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                            .tint(ReefColors.primary)
                        Text("thinking")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(colors.textMuted)
                    }
                } else {
                    Text("idle")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if tutorEvalService.chatMessages.isEmpty {
                            // Empty state
                            VStack(spacing: 8) {
                                Text("Your work and feedback will appear here")
                                    .font(.epilogue(12, weight: .medium))
                                    .foregroundStyle(colors.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(tutorEvalService.chatMessages) { message in
                                chatBubble(message: message, colors: colors)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    if let last = tutorEvalService.chatMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: tutorEvalService.chatMessages.count) { _, _ in
                    if let last = tutorEvalService.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Chat input bar
            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            HStack(spacing: 8) {
                TextField("Ask the tutor...", text: $chatInput)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundStyle(colors.text)
                    .submitLabel(.send)
                    .onSubmit { submitChat() }

                Button(action: submitChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? colors.textMuted
                            : ReefColors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tutorEvalService.isSendingChat)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func submitChat() {
        let message = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        chatInput = ""
        onSendChat?(message)
    }

    // MARK: - Chat Bubble

    private func bubbleConfig(for role: TutorChatMessage.Role) -> (icon: String, label: String, color: Color) {
        switch role {
        case .student:
            return ("pencil.line", "You", .clear)
        case .error:
            return ("exclamationmark.triangle.fill", "Error", Color(hex: 0xE57373))
        case .reinforcement:
            return ("checkmark.circle.fill", "Nice", Color(hex: 0x81C784))
        case .answer:
            return ("brain.head.profile", "Tutor", ReefColors.primary)
        }
    }

    @ViewBuilder
    private func chatBubble(message: TutorChatMessage, colors: ReefThemeColors) -> some View {
        let isStudent = message.role == .student
        let config = bubbleConfig(for: message.role)

        HStack {
            if isStudent { Spacer(minLength: 24) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: config.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(config.label)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(isStudent ? colors.textMuted : config.color)

                MathText(
                    text: message.latex,
                    fontSize: 13,
                    color: colors.text
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isStudent
                          ? (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                          : config.color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isStudent ? Color.clear : config.color.opacity(0.25), lineWidth: 1)
            )

            if !isStudent { Spacer(minLength: 24) }
        }
    }
}
