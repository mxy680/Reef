import SwiftUI

/// Interactive tutorial overlay for the canvas demo during onboarding.
/// 3 steps: write something → meet the tutor → try solving.
struct TutorDemoOverlay: View {
    @Environment(ReefTheme.self) private var theme

    @Binding var tutorialStep: TutorialStep
    let onDismiss: () -> Void

    enum TutorialStep: Int {
        case writeHere = 0
        case meetTutor = 1
        case trySolving = 2
        case done = 3
    }

    @State private var showHintTip = false
    @State private var hintTimer: Task<Void, Never>?
    @State private var isPulsing = false

    var body: some View {
        let colors = theme.colors

        ZStack {
            switch tutorialStep {
            case .writeHere:
                writeHereStep

            case .meetTutor:
                meetTutorStep

            case .trySolving:
                // No full overlay — just the contextual hint tip after idle
                if showHintTip {
                    hintTipView
                }

            case .done:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tutorialStep)
        .onChange(of: tutorialStep) { _, newStep in
            showHintTip = false
            hintTimer?.cancel()
            if newStep == .trySolving {
                startHintTimer()
            }
        }
    }

    // MARK: - Step 1: Write Here

    private var writeHereStep: some View {
        let colors = theme.colors

        return ZStack {
            // Dim overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Callout card
            VStack(spacing: 16) {
                // Pulsing pencil icon
                ZStack {
                    Circle()
                        .fill(ReefColors.primary.opacity(0.2))
                        .frame(width: 72, height: 72)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)

                    Image(systemName: "pencil.tip")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(ReefColors.primary)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }

                Text("Start writing anywhere")
                    .font(.epilogue(22, weight: .black))
                    .tracking(-0.04 * 22)
                    .foregroundStyle(colors.text)

                Text("Use your Apple Pencil to write on the page.\nRest your palm naturally — it won't interfere.")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(32)
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
            .frame(maxWidth: 400)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        .allowsHitTesting(false) // Let pencil strokes pass through
    }

    // MARK: - Step 2: Meet Tutor

    private var meetTutorStep: some View {
        let colors = theme.colors

        return ZStack {
            // Dim overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Callout card
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(ReefColors.primary)

                Text("Meet your AI tutor")
                    .font(.epilogue(22, weight: .black))
                    .tracking(-0.04 * 22)
                    .foregroundStyle(colors.text)

                Text("Your tutor watches your work in real time.\nIt'll speak up when you make progress — or a mistake.")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                ReefButton("Got it", size: .compact, action: {
                    tutorialStep = .trySolving
                })
                .frame(maxWidth: 160)
            }
            .padding(32)
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
            .frame(maxWidth: 400)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    // MARK: - Step 3: Hint Tip (contextual, appears after idle)

    private var hintTipView: some View {
        VStack {
            Spacer()
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ReefColors.primary)

                    Text("Stuck? Tap the 💡 in the sidebar for a hint.")
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(theme.colors.text)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.colors.border, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))

                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, 80) // Above the Done button
        }
        .allowsHitTesting(false)
    }

    // MARK: - Hint Timer

    private func startHintTimer() {
        hintTimer?.cancel()
        hintTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.4)) {
                showHintTip = true
            }
        }
    }

    /// Call this from outside when the student writes a new stroke (resets the idle timer).
    func resetHintTimer() {
        showHintTip = false
        if tutorialStep == .trySolving {
            startHintTimer()
        }
    }
}
