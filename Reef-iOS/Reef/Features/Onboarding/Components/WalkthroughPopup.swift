import SwiftUI

/// Persistent walkthrough card with typewriter text animation.
/// Card stays in place — only the text inside changes.
struct WalkthroughCard: View {
    @Environment(ReefTheme.self) private var theme

    let step: WalkthroughStep?
    let onGotIt: () -> Void

    @State private var displayedText = ""
    @State private var showButton = false
    @State private var typingTask: Task<Void, Never>?
    private let charDelay: UInt64 = 20_000_000 // 20ms per character

    var body: some View {
        let colors = theme.colors

        VStack(alignment: .leading, spacing: 12) {
            Text(displayedText)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Reserve height so card doesn't jump
                .frame(minHeight: 40)

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
        .onChange(of: step) { _, newStep in
            startTyping(newStep?.text ?? "")
        }
        .onAppear {
            startTyping(step?.text ?? "")
        }
    }

    private func startTyping(_ text: String) {
        typingTask?.cancel()
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
