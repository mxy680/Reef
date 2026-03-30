import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    @Bindable var viewModel: CanvasViewModel
    var onSendChat: ((String) -> Void)?

    @State private var chatInput: String = ""

    private var tutorStatus: String {
        if viewModel.tutorEvalService.isSendingChat { return "writing" }
        if viewModel.tutorEvalService.isEvaluating { return "thinking" }
        return "idle"
    }

    var body: some View {
        let colors = ReefThemeColors(isDarkMode: isDarkMode)

        HStack(spacing: 0) {
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.2))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                // === Collapsible Hint/Answer Panels ===
                if viewModel.tutorModeOn, viewModel.currentHintStep != nil {
                    hintAnswerSection(colors: colors)
                }

                // === Tutor Chat (takes remaining space) ===
                if viewModel.tutorModeOn {
                    Rectangle()
                        .fill(colors.divider)
                        .frame(height: 1)

                    tutorChatSection(colors: colors)
                        .frame(maxHeight: .infinity)
                }
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
    }

    // MARK: - Hint / Answer Section

    @ViewBuilder
    private func hintAnswerSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hint panel
            collapsiblePanel(
                title: "Hint",
                icon: "lightbulb.fill",
                isExpanded: viewModel.showHintPopover,
                accentColor: Color(hex: 0xF5A623),
                colors: colors
            ) {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.showHintPopover.toggle()
                }
            } content: {
                if let step = viewModel.currentHintStep {
                    MathText(
                        text: step.explanation,
                        fontSize: 13,
                        color: colors.text
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }

            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            // Answer panel
            collapsiblePanel(
                title: "Full Solution",
                icon: "eye.fill",
                isExpanded: viewModel.showRevealPopover,
                accentColor: ReefColors.primary,
                colors: colors
            ) {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.showRevealPopover.toggle()
                }
            } content: {
                if let step = viewModel.currentHintStep {
                    ScrollView {
                        MathText(
                            text: step.work,
                            fontSize: 13,
                            color: colors.text
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.25), value: viewModel.showHintPopover)
        .animation(.spring(duration: 0.25), value: viewModel.showRevealPopover)
    }

    @ViewBuilder
    private func collapsiblePanel(
        title: String,
        icon: String,
        isExpanded: Bool,
        accentColor: Color,
        colors: ReefThemeColors,
        toggle: @escaping () -> Void,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tappable
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReefColors.primary)
                        .frame(width: 16, alignment: .center)

                    Text(title)
                        .font(.epilogue(13, weight: .black))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.text)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(colors.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content — collapsible
            if isExpanded {
                content()
            }
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
                    .foregroundStyle(ReefColors.primary)
                    .frame(width: 16, alignment: .center)
                Text("Tutor")
                    .font(.epilogue(13, weight: .black))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)

                Spacer()

                HStack(spacing: 4) {
                    if tutorStatus != "idle" {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                            .tint(ReefColors.primary)
                    }
                    Text(tutorStatus)
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
                        if viewModel.tutorEvalService.chatMessages.isEmpty {
                            VStack(spacing: 8) {
                                Text("Your work and feedback will appear here")
                                    .font(.epilogue(12, weight: .medium))
                                    .foregroundStyle(colors.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(viewModel.tutorEvalService.chatMessages) { message in
                                chatBubble(message: message, colors: colors)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    if let last = viewModel.tutorEvalService.chatMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.tutorEvalService.chatMessages.count) { _, _ in
                    if let last = viewModel.tutorEvalService.chatMessages.last {
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
                TextField("Ask the tutor...", text: $chatInput, prompt: Text("Ask the tutor...").foregroundStyle(colors.textMuted))
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
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.tutorEvalService.isSendingChat)
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
        case .confidenceCheck:
            return ("gauge.with.needle.fill", "Check-in", ReefColors.primary)
        }
    }

    @ViewBuilder
    private func chatBubble(message: TutorChatMessage, colors: ReefThemeColors) -> some View {
        if message.role == .confidenceCheck {
            confidenceCheckBubble(message: message, colors: colors)
        } else {

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
        } // end else (not confidenceCheck)
    }

    // MARK: - Confidence Check Bubble

    @ViewBuilder
    private func confidenceCheckBubble(message: TutorChatMessage, colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Check-in")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ReefColors.primary)

            Text(message.latex)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colors.text)

            if let response = message.confidenceResponse {
                // Already answered
                HStack(spacing: 6) {
                    Image(systemName: response == "solid" ? "checkmark.circle.fill" : response == "okay" ? "minus.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(response == "solid" ? Color(hex: 0x81C784) : response == "okay" ? ReefColors.primary : Color(hex: 0xF5A623))
                    Text(response.capitalized)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(colors.textMuted)
                }
            } else {
                // Show pills
                HStack(spacing: 8) {
                    ForEach(["shaky", "okay", "solid"], id: \.self) { level in
                        Button {
                            respondToConfidence(messageId: message.id, response: level)
                        } label: {
                            Text(level.capitalized)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(colors.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(colors.card)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(colors.border, lineWidth: 1.5))
                                .background(Capsule().fill(colors.shadow).offset(x: 2, y: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ReefColors.primary.opacity(0.2), lineWidth: 1)
        )
    }

    private func respondToConfidence(messageId: UUID, response: String) {
        if let idx = viewModel.tutorEvalService.chatMessages.firstIndex(where: { $0.id == messageId }) {
            viewModel.tutorEvalService.chatMessages[idx].confidenceResponse = response

            // Store in Supabase
            let hadMistake = viewModel.tutorEvalService.chatMessages[0..<idx].contains { $0.role == .error }
            Task {
                await storeConfidenceLog(
                    documentId: viewModel.document.id,
                    questionNumber: viewModel.activeQuestionNumber,
                    stepIndex: viewModel.currentTutorStepIndex,
                    confidence: response,
                    hadMistake: hadMistake
                )
            }
        }
    }

    private nonisolated func storeConfidenceLog(documentId: String, questionNumber: Int, stepIndex: Int, confidence: String, hadMistake: Bool) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }
        _ = try? await supabase
            .from("confidence_logs")
            .insert([
                "user_id": userId,
                "document_id": documentId,
                "question_number": "\(questionNumber)",
                "step_index": "\(stepIndex)",
                "confidence": confidence,
                "had_mistake": hadMistake ? "true" : "false",
            ] as [String: String])
            .execute()
    }
}
