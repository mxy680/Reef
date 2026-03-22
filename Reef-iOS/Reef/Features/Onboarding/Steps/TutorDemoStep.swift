import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var messageText = ""

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    Text("Try it out")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    if demoService.isGenerating {
                        generatingView
                    } else if demoService.isReady {
                        problemCard(colors: colors)
                        chatFeed(colors: colors)
                        messageInput
                    } else if let errorMessage = demoService.error {
                        errorView(message: errorMessage, colors: colors)
                    }

                    // Done button — always visible
                    ReefButton("Done — show me my plan", action: { viewModel.goNext() })
                        .fadeUp(index: 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .onAppear {
            if !demoService.isReady && !demoService.isGenerating {
                Task {
                    await demoService.generateProblem(
                        topic: viewModel.answers.favoriteTopic,
                        studentType: viewModel.answers.studentType?.rawValue ?? "college"
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ReefColors.primary)
            Text("Cooking up a problem...")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .fadeUp(index: 1)
    }

    private func problemCard(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR PROBLEM")
                .font(.epilogue(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(colors.textMuted)

            Text(demoService.questionText)
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReefColors.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fadeUp(index: 1)
    }

    private func chatFeed(colors: ReefThemeColors) -> some View {
        VStack(spacing: 10) {
            ForEach(demoService.chatMessages) { message in
                chatBubble(message: message, colors: colors)
            }

            if demoService.isSending {
                HStack {
                    ProgressView()
                        .tint(ReefColors.primary)
                        .scaleEffect(0.8)
                    Text("thinking...")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                .padding(.leading, 8)
            }
        }
        .fadeUp(index: 2)
    }

    private var messageInput: some View {
        HStack(spacing: 10) {
            ReefTextField(
                placeholder: "Ask your tutor anything...",
                text: $messageText,
                capitalization: .sentences,
                autocorrection: true,
                onSubmit: { sendMessage() }
            )

            ReefButton(.primary, size: .compact, action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 44)
            .opacity(messageText.isEmpty ? 0.5 : 1)
        }
        .fadeUp(index: 3)
    }

    private func errorView(message: String, colors: ReefThemeColors) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't generate a problem")
                .font(.epilogue(15, weight: .bold))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.text)

            Text(message)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .fadeUp(index: 1)
    }

    // MARK: - Chat Bubble

    private func chatBubble(message: DemoChatMessage, colors: ReefThemeColors) -> some View {
        let isTutor = message.role == .tutor

        return HStack {
            if !isTutor { Spacer(minLength: 60) }

            Text(message.text)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(isTutor ? colors.text : ReefColors.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isTutor ? colors.subtle : ReefColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if isTutor { Spacer(minLength: 60) }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        Task {
            await demoService.sendMessage(text)
        }
    }
}
