import SwiftUI

struct CanvasLoadingView: View {
    let isLoadingAnswerKeys: Bool
    let answerKeyFailed: Bool
    let documentName: String
    var onClose: (() -> Void)?
    var onRetry: (() -> Void)?

    @State private var isPulsing = false
    @State private var dotCount = 0
    @State private var messageIndex = 0
    @State private var dotTask: Task<Void, Never>?
    @State private var messageTask: Task<Void, Never>?

    private var dots: String {
        String(repeating: ".", count: dotCount + 1)
    }

    private var answerKeyMessages: [String] {
        [
            "Teaching your tutor the problem",
            "Reading the figures carefully",
            "Building step-by-step solutions",
            "Almost ready",
        ]
    }

    private var currentMessage: String {
        if isLoadingAnswerKeys {
            return answerKeyMessages[min(messageIndex, answerKeyMessages.count - 1)]
        }
        return "Loading \(documentName)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Close button
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(20)
                .zIndex(1)
            }

        if answerKeyFailed {
            // Failure state
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.orange)

                Text("Couldn't generate solutions")
                    .font(.epilogue(16, weight: .bold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(.primary.opacity(0.7))

                Text("This can happen with complex or unusual problems. You can still use the canvas without the tutor.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)

                HStack(spacing: 12) {
                    if let onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(ReefColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let onClose {
                        Button("Continue without tutor") {
                            onClose()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 28) {
                // Animated icon
                ZStack {
                    Circle()
                        .stroke(ReefColors.primary.opacity(isPulsing ? 0.15 : 0.05), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)

                    Circle()
                        .fill(ReefColors.primary.opacity(0.1))
                        .frame(width: 72, height: 72)

                    Image(systemName: isLoadingAnswerKeys ? "brain.head.profile" : "doc.text")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(ReefColors.primary)
                        .scaleEffect(isPulsing ? 1.05 : 0.95)
                }

                VStack(spacing: 8) {
                    Text(currentMessage + dots)
                        .font(.epilogue(16, weight: .bold))
                        .tracking(-0.04 * 16)
                        .foregroundStyle(.primary.opacity(0.7))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: messageIndex)

                    if isLoadingAnswerKeys {
                        Text("This takes a minute for complex problems")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        } // end ZStack
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }

            dotTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    dotCount = (dotCount + 1) % 3
                }
            }

            if isLoadingAnswerKeys {
                messageTask = Task { @MainActor in
                    for i in 1..<answerKeyMessages.count {
                        try? await Task.sleep(for: .seconds(8))
                        guard !Task.isCancelled else { return }
                        withAnimation { messageIndex = i }
                    }
                }
            }
        }
        .onDisappear {
            dotTask?.cancel()
            messageTask?.cancel()
        }
    }
}
