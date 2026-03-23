import SwiftUI

/// Persistent walkthrough card with typewriter text animation.
/// Card stays in place — only the text inside changes.
struct WalkthroughCard: View {
    @Environment(ReefTheme.self) private var theme

    let step: WalkthroughStep?
    var reactionPrefix: String? = nil
    var readyToType: Bool = true  // Set to false to wait for TTS before typing
    let onGotIt: () -> Void

    @State private var displayedText = ""
    @State private var showButton = false
    @State private var typingTask: Task<Void, Never>?
    @State private var thinkingDots = ""
    @State private var thinkingTask: Task<Void, Never>?
    private let charDelay: UInt64 = 20_000_000 // 20ms per character

    private var fullText: String {
        let stepText = step?.text ?? ""
        if let reaction = reactionPrefix, step == .tryHighlighter {
            return reaction + "\n\n" + stepText
        }
        return stepText
    }

    var body: some View {
        let colors = theme.colors

        VStack(alignment: .leading, spacing: 12) {
            if !readyToType && displayedText.isEmpty {
                // Thinking animation while waiting for TTS
                Text("thinking\(thinkingDots)")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.textMuted)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { startThinking() }
                    .onDisappear { thinkingTask?.cancel() }
            } else {
                Text(displayedText)
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showButton, let step, !step.requiresAction {
                ReefButton(step.buttonLabel, size: .compact, action: onGotIt)
                    .frame(maxWidth: 140)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colors.border, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colors.shadow)
                .offset(x: 3, y: 3)
        )
        .animation(.easeInOut(duration: 0.15), value: showButton)
        .onChange(of: step) { _, _ in
            if readyToType {
                startTyping(fullText)
            } else {
                displayedText = ""
                showButton = false
            }
        }
        .onChange(of: readyToType) { _, ready in
            if ready && displayedText.isEmpty {
                startTyping(fullText)
            }
        }
        .onChange(of: reactionPrefix) { _, _ in
            if step == .tryHighlighter && readyToType {
                startTyping(fullText)
            }
        }
        .onAppear {
            if readyToType {
                startTyping(fullText)
            }
        }
    }

    private func startThinking() {
        thinkingTask?.cancel()
        thinkingDots = ""
        thinkingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
                guard !Task.isCancelled else { return }
                thinkingDots = thinkingDots.count >= 3 ? "" : thinkingDots + "."
            }
        }
    }

    private func startTyping(_ text: String) {
        typingTask?.cancel()
        thinkingTask?.cancel()
        displayedText = ""
        showButton = false

        guard !text.isEmpty else { return }

        typingTask = Task { @MainActor in
            for char in text {
                guard !Task.isCancelled else { return }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: charDelay)
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                showButton = true
            }
        }
    }
}
