import SwiftUI
import PencilKit

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?
    @State private var walkthrough = CanvasWalkthroughState()
    @State private var showPreDialog = true
    @State private var pendingReactionTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let canvasVM {
                // Full canvas experience
                CanvasView(viewModel: canvasVM, walkthroughStep: walkthrough.currentStep, onDismiss: {
                    viewModel.goNext()
                })

                // Pre-walkthrough dialog — sound + pencil check
                if showPreDialog {
                    preDialog
                        .zIndex(400)
                        .transition(.opacity)
                }

                // Walkthrough — persistent card with typewriter text
                if !walkthrough.isComplete && !showPreDialog {
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()

                        // Card — always present, text changes inside
                        WalkthroughCard(
                            step: walkthrough.currentStep,
                            reactionPrefix: walkthrough.drawingReaction,
                            readyToType: walkthrough.isSpeaking,
                            onGotIt: { walkthrough.advance() }
                        )

                        // Skip — always visible, never animates
                        ReefButton(.primary, size: .compact, action: {
                            walkthrough.skip()
                        }) {
                            Text("Skip tutorial")
                                .font(.epilogue(11, weight: .bold))
                                .tracking(-0.04 * 11)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    .zIndex(300)
                    .transition(.opacity)
                }

                // Floating "Done" button — only after walkthrough
                if walkthrough.isComplete {
                    VStack {
                        Spacer()
                        HStack {
                            ReefButton("Done — show me my plan", size: .compact, action: {
                                viewModel.goNext()
                            })
                            .padding(20)
                            Spacer()
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(200)
                    .transition(.opacity)
                }
            } else {
                loadingCard
            }
        }
        .onAppear {
            if !demoService.isReady && !demoService.isGenerating {
                Task {
                    await demoService.generateDocument(
                        topic: viewModel.answers.favoriteTopic,
                        studentType: viewModel.answers.studentType?.rawValue ?? "college"
                    )
                    if let doc = demoService.demoDocument {
                        viewModel.demoDocumentId = doc.id
                        let vm = CanvasViewModel(document: doc)
                        vm.deferTutorMode = true  // Walkthrough controls when tutor enables
                        canvasVM = vm
                    }
                }
            }
        }
        // Speak first step when pre-dialog is dismissed
        .onChange(of: showPreDialog) { _, showing in
            if !showing && walkthrough.currentStep == .drawSomething {
                walkthrough.speakInstruction(WalkthroughStep.drawSomething.speech)
            }
        }
        // MARK: - Walkthrough Detection (1000ms after pen lift)
        .onChange(of: canvasVM?.drawingManager.drawingVersion) { _, _ in
            guard let vm = canvasVM else { return }
            walkthrough.log("drawingVersion changed, step=\(String(describing: walkthrough.currentStep)), waiting=\(walkthrough.waitingForReaction)")
            guard !walkthrough.waitingForReaction else { return }

            switch walkthrough.currentStep {
            case .drawSomething:
                if vm.drawingManager.hasDrawing(for: vm.currentPageIndex) {
                    walkthrough.log("hasDrawing=true, scheduling reaction in 1000ms")
                    walkthrough.cancelPendingAdvance()
                    pendingReactionTask?.cancel()
                    pendingReactionTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1000))
                        guard !Task.isCancelled else { return }
                        walkthrough.log("1000ms elapsed, capturing image...")
                        if let image = vm.captureActiveQuestionImage() {
                            walkthrough.log("image captured (\(image.count) chars), sending reaction")
                            walkthrough.reactToDrawing(imageBase64: image)
                        } else {
                            walkthrough.log("captureActiveQuestionImage returned nil, advancing")
                            walkthrough.advance()
                        }
                    }
                } else {
                    walkthrough.log("hasDrawing=false")
                }

            case .tryHighlighter:
                if vm.selectedTool == .highlighter && vm.drawingManager.hasDrawing(for: vm.currentPageIndex) {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .eraseHighlight:
                if vm.selectedTool == .eraser {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .shapeTool:
                if vm.selectedTool == .shapes {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .lassoTool:
                if vm.selectedTool == .lasso {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .fingerDraw:
                if vm.selectedTool == .handDraw {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            default:
                break
            }
        }
        // Detect ruler/calculator/page settings individually
        .onChange(of: canvasVM?.showRuler) { _, isOn in
            if isOn == true && walkthrough.currentStep == .ruler {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        .onChange(of: canvasVM?.showCalculator) { _, isOn in
            if isOn == true && walkthrough.currentStep == .calculator {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        .onChange(of: canvasVM?.showPageSettings) { _, isOn in
            if isOn == true && walkthrough.currentStep == .pageSettings {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        // Detect voice command (mic) — wait for tutor to finish responding
        .onChange(of: canvasVM?.isMicOn) { _, isOn in
            if isOn == true && walkthrough.currentStep == .voiceCommand {
                walkthrough.log("Mic activated during voiceCommand step, waiting for tutor response...")
            }
        }
        .onChange(of: canvasVM?.tutorEvalService.isSendingChat) { _, isSending in
            if isSending == false && walkthrough.currentStep == .voiceCommand {
                // Tutor finished responding — wait for audio, then advance
                if canvasVM?.tutorEvalService.chatMessages.contains(where: { $0.role == .answer }) == true {
                    Task { @MainActor in
                        // Wait for tutor audio to finish playing
                        while canvasVM?.tutorEvalService.isTutorSpeaking == true {
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                        try? await Task.sleep(for: .milliseconds(500))
                        walkthrough.advance()
                    }
                }
            }
        }
        // Detect sidebar toggle
        .onChange(of: canvasVM?.showSidebar) { _, isOn in
            if walkthrough.currentStep == .sidebarToggle {
                walkthrough.advanceAfterDelay(ms: 1000)
            }
        }
        // Detect bug report
        .onChange(of: canvasVM?.showBugReport) { _, isOn in
            if isOn == true && walkthrough.currentStep == .bugReport {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        // Detect export
        .onChange(of: canvasVM?.showExportPreview) { _, isOn in
            if isOn == true && walkthrough.currentStep == .exportFeature {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        // Detect hint and reveal
        .onChange(of: canvasVM?.showHintPopover) { _, isOn in
            if isOn == true && walkthrough.currentStep == .tutorHint {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        .onChange(of: canvasVM?.showRevealPopover) { _, isOn in
            if isOn == true && walkthrough.currentStep == .tutorReveal {
                walkthrough.advanceAfterDelay(ms: 1500)
            }
        }
        // Detect problem solved — tutor progress reaches 100%
        .onChange(of: canvasVM?.tutorEvalService.status) { _, status in
            if status == "completed" && walkthrough.currentStep == .solveIt {
                if let vm = canvasVM, vm.currentTutorStepIndex >= vm.tutorStepCount - 1 {
                    // Wait for tutor's congratulations audio to finish
                    Task { @MainActor in
                        while canvasVM?.tutorEvalService.isTutorSpeaking == true {
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                        try? await Task.sleep(for: .milliseconds(500))
                        walkthrough.advance()
                    }
                }
            }
        }
        // Speak step instructions + handle drawing reaction flow
        .onChange(of: walkthrough.currentStep) { oldStep, newStep in
            // Speak step instructions (skip if coming from drawSomething — reactToDrawing handles that)
            if let step = newStep, oldStep != .drawSomething {
                let speechText = step.speech

                // Wait for real tutor audio to finish before walkthrough speaks
                if canvasVM?.tutorEvalService.isTutorSpeaking == true {
                    Task { @MainActor in
                        // Poll until tutor finishes speaking
                        while canvasVM?.tutorEvalService.isTutorSpeaking == true {
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                        try? await Task.sleep(for: .milliseconds(500)) // brief pause
                        walkthrough.speakInstruction(speechText)
                    }
                } else {
                    walkthrough.speakInstruction(speechText)
                }

                // Auto-complete ready step after speaking
                if step == .ready {
                    walkthrough.advanceAfterDelay(ms: 4000)
                }
            }

            // When walkthrough reaches enableTutor, allow the toggle
            if newStep == .enableTutor {
                canvasVM?.deferTutorMode = false
            }
        }
        .onChange(of: canvasVM?.tutorModeOn) { _, isOn in
            if isOn == true && walkthrough.currentStep == .enableTutor {
                // User toggled tutor on — finish setup that was deferred
                if let vm = canvasVM {
                    vm.showSidebar = true
                    if vm.activeQuestionLabel == nil {
                        vm.activeQuestionLabel = "Q1a"
                    }
                }
                withAnimation { walkthrough.advance() }
            }
        }
    }

    // MARK: - Pre-Dialog

    private var preDialog: some View {
        let colors = theme.colors

        return ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Teal header
                VStack(spacing: 10) {
                    Text("🎧")
                        .font(.system(size: 36))

                    Text("Before we start")
                        .font(.epilogue(24, weight: .black))
                        .tracking(-0.04 * 24)
                        .foregroundStyle(ReefColors.white)

                    Text("Two quick things.")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .background(ReefColors.primary)

                // Checklist items
                VStack(spacing: 0) {
                    preDialogRow(
                        icon: "speaker.wave.2.fill",
                        title: "Sound on",
                        subtitle: "Your tutor talks out loud."
                    )

                    Rectangle()
                        .fill(colors.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    preDialogRow(
                        icon: "applepencil.gen2",
                        title: "Apple Pencil ready",
                        subtitle: "You'll write on the canvas."
                    )
                }
                .padding(.vertical, 8)

                // CTA
                ReefButton("I'm ready", action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showPreDialog = false
                    }
                })
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
            .frame(maxWidth: 360)
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
        }
    }

    private func preDialogRow(icon: String, title: String, subtitle: String) -> some View {
        let colors = theme.colors

        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReefColors.primary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ReefColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.epilogue(15, weight: .bold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(colors.text)

                Text(subtitle)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ReefColors.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Loading Card

    @State private var isPulsing = false
    @State private var messageIndex = 0
    @State private var loadingTasks: [Task<Void, Never>] = []

    private var currentLoadingMessage: String {
        let topic = viewModel.answers.favoriteTopic
        let messages = [
            "Generating a problem just for you...",
            "Compiling the math...",
            topic.isEmpty ? "Training your tutor..." : "Teaching your tutor about \(topic)...",
            "Almost ready...",
        ]
        return messages[min(messageIndex, messages.count - 1)]
    }

    private var loadingCard: some View {
        let colors = theme.colors

        return GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Try it out")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    if demoService.isGenerating {
                        generatingView
                    } else if let errorMessage = demoService.error {
                        errorView(message: errorMessage, colors: colors)
                    }
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
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ReefColors.primary.opacity(isPulsing ? 0.15 : 0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(ReefColors.primary)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)
            }

            Text(currentLoadingMessage)
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(theme.colors.text)
                .multilineTextAlignment(.center)
                .id(messageIndex)
                .transition(.opacity)

            Text("Fun fact: this problem didn't exist 10 seconds ago")
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(theme.colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            for i in 1...3 {
                let task = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Double(i) * 2.5))
                    withAnimation(.easeInOut(duration: 0.3)) { messageIndex = i }
                }
                loadingTasks.append(task)
            }
        }
        .onDisappear {
            loadingTasks.forEach { $0.cancel() }
            loadingTasks.removeAll()
        }
        .fadeUp(index: 1)
    }

    // MARK: - Error View

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

            ReefButton("Try again", size: .compact, action: {
                Task {
                    await demoService.generateDocument(
                        topic: viewModel.answers.favoriteTopic,
                        studentType: viewModel.answers.studentType?.rawValue ?? "college"
                    )
                    if let doc = demoService.demoDocument {
                        viewModel.demoDocumentId = doc.id
                        canvasVM = CanvasViewModel(document: doc)
                    }
                }
            })
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .fadeUp(index: 1)
    }
}
