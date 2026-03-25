import SwiftUI
import PencilKit

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?
    @State private var walkthrough = CanvasWalkthroughState()
    @State private var showVoiceChoice = true
    @State private var voiceMode = true
    @State private var showExpChoice = false
    @State private var showSkipToolsChoice = false
    @State private var showPreDialog = false
    @State private var introReady = true
    @State private var introTask: Task<Void, Never>?
    @State private var pendingReactionTask: Task<Void, Never>?

    private let introDisplay = "Alright, quick intro. I'm your AI tutor. I watch everything you write in real time — yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line, no awkward eye contact. Dive in — the reef's got you covered."

    private let introSpeech = "Alright, quick intro. I'm your A.I. tutor. I watch EVERYTHING you write in real time. Yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line. No awkward eye contact. Dive in. The reef's got you covered."

    var body: some View {
        ZStack {
            if let canvasVM {
                // Full canvas experience
                CanvasView(viewModel: canvasVM, walkthroughStep: walkthrough.currentStep, onDismiss: {
                    viewModel.goNext()
                })

                // Voice choice dialog
                if showVoiceChoice {
                    voiceChoiceDialog
                        .zIndex(500)
                        .transition(.opacity)
                }

                // Experience question
                if showExpChoice {
                    experienceChoiceDialog
                        .zIndex(450)
                        .transition(.opacity)
                }

                // Skip tools question
                if showSkipToolsChoice {
                    skipToolsChoiceDialog
                        .zIndex(450)
                        .transition(.opacity)
                }

                // Pre-walkthrough dialog — tutor intro
                if showPreDialog && !showVoiceChoice && !showExpChoice && !showSkipToolsChoice {
                    preDialog
                        .zIndex(400)
                        .transition(.opacity)
                }

                // Walkthrough — persistent card with typewriter text
                if !walkthrough.isComplete && !showPreDialog && !showVoiceChoice && !showExpChoice && !showSkipToolsChoice {
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()

                        // Card — always present, text changes inside
                        WalkthroughCard(
                            step: walkthrough.currentStep,
                            reactionPrefix: walkthrough.drawingReaction,
                            readyToType: voiceMode ? walkthrough.isSpeaking : true,
                            onGotIt: { walkthrough.advance() }
                        )

                        // Skip + Restart — always visible
                        HStack(spacing: 8) {
                            ReefButton(.primary, size: .compact, action: {
                                walkthrough.skip()
                            }) {
                                Text("Skip tutorial")
                                    .font(.epilogue(11, weight: .bold))
                                    .tracking(-0.04 * 11)
                            }

                            ReefButton(.secondary, size: .compact, action: {
                                walkthrough.restart()
                            }) {
                                Text("Restart")
                                    .font(.epilogue(11, weight: .bold))
                                    .tracking(-0.04 * 11)
                            }
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
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
        // Speak first step when pre-dialog is dismissed (voice mode only)
        .onChange(of: showPreDialog) { _, showing in
            if !showing && walkthrough.currentStep == .drawSomething && voiceMode {
                walkthrough.speakInstruction(WalkthroughStep.drawSomething.speech)
            }
        }
        // MARK: - Walkthrough Detection (1000ms after pen lift)
        .onChange(of: canvasVM?.drawingManager.drawingVersion) { _, _ in
            guard !showPreDialog && !showVoiceChoice && !showExpChoice && !showSkipToolsChoice else { return }
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
                        await waitForTutorAudio()
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
                    Task { @MainActor in
                        await waitForTutorAudio()
                        walkthrough.advance()
                    }
                }
            }
        }
        // Speak step instructions + handle drawing reaction flow
        .onChange(of: walkthrough.currentStep) { oldStep, newStep in
            // Speak step instructions (skip if coming from drawSomething — reactToDrawing handles that)
            if let step = newStep, oldStep != .drawSomething, voiceMode {
                let speechText = step.speech

                // Wait for real tutor audio to finish before walkthrough speaks
                if canvasVM?.tutorEvalService.isTutorSpeaking == true {
                    Task { @MainActor in
                        await waitForTutorAudio()
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

    // MARK: - Voice Choice Dialog

    private var voiceChoiceDialog: some View {
        let colors = theme.colors

        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text("Before we start — do you want me to talk out loud, or keep it text-only?")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .lineSpacing(3)
                .foregroundStyle(colors.text)
                .padding(16)
                .frame(maxWidth: 340, alignment: .leading)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 14).fill(colors.shadow).offset(x: 3, y: 3))

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: {
                    voiceMode = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showVoiceChoice = false
                        showExpChoice = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                        Text("Voice on")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(-0.04 * 11)
                    }
                }

                ReefButton(.secondary, size: .compact, action: {
                    voiceMode = false
                    withAnimation(.easeOut(duration: 0.25)) {
                        showVoiceChoice = false
                        showExpChoice = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 10))
                        Text("Text only")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(-0.04 * 11)
                    }
                }
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Experience Choice Dialog

    private var experienceChoiceDialog: some View {
        let colors = theme.colors

        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text("Have you used a note-taking app before? GoodNotes, Notability, OneNote — anything like that?")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .lineSpacing(3)
                .foregroundStyle(colors.text)
                .padding(16)
                .frame(maxWidth: 340, alignment: .leading)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 14).fill(colors.shadow).offset(x: 3, y: 3))

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showExpChoice = false
                        showSkipToolsChoice = true
                    }
                }) {
                    Text("Yeah")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showExpChoice = false
                        showPreDialog = true
                    }
                }) {
                    Text("Nope, first time")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Skip Tools Choice Dialog

    private var skipToolsChoiceDialog: some View {
        let colors = theme.colors

        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text("Nice — then you already know the basics. Want to skip the drawing tools tutorial and jump straight to the AI tutor?")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .lineSpacing(3)
                .foregroundStyle(colors.text)
                .padding(16)
                .frame(maxWidth: 340, alignment: .leading)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 14).fill(colors.shadow).offset(x: 3, y: 3))

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: {
                    // Skip to Phase 2 (enableTutor)
                    walkthrough.isSpeaking = true  // Ensure popup types immediately
                    walkthrough.currentStep = .enableTutor
                    canvasVM?.deferTutorMode = false  // Allow tutor toggle
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSkipToolsChoice = false
                    }
                }) {
                    Text("Skip to tutor")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSkipToolsChoice = false
                        showPreDialog = true
                    }
                }) {
                    Text("Show me everything")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Audio Wait Helper

    /// Wait for tutor audio to finish with a 15-second timeout to prevent infinite loops.
    private func waitForTutorAudio() async {
        var waited = 0
        while canvasVM?.tutorEvalService.isTutorSpeaking == true, waited < 75 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 1
        }
        try? await Task.sleep(for: .milliseconds(500))
    }

    // MARK: - Pre-Dialog (Tutor Introduction)

    private var preDialog: some View {
        let colors = theme.colors

        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text(introDisplay)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .lineSpacing(3)
                .foregroundStyle(colors.text)
                .padding(16)
                .frame(maxWidth: 340, alignment: .leading)
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

            ReefButton(.primary, size: .compact, action: {
                withAnimation(.easeOut(duration: 0.25)) {
                    showPreDialog = false
                }
            }) {
                Text("Let's go")
                    .font(.epilogue(11, weight: .bold))
                    .tracking(-0.04 * 11)
            }
            .opacity(introReady ? 1 : 0.4)
            .disabled(!introReady)
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .onAppear {
            speakIntro()
        }
        .onDisappear {
            introTask?.cancel()
        }
    }

    private func speakIntro() {
        guard voiceMode else { return }
        introTask = Task { @MainActor in
            // Enable button after a short fallback delay in case TTS fails
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if !introReady { introReady = true }
            }

            guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                  let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
                  let token = try? await supabase.auth.session.accessToken else {
                introReady = true
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": introSpeech])

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                introReady = true
                return
            }

            struct TTSResponse: Decodable {
                let speechAudio: String?
                enum CodingKeys: String, CodingKey { case speechAudio = "speech_audio" }
            }

            guard let result = try? JSONDecoder().decode(TTSResponse.self, from: data),
                  let audioBase64 = result.speechAudio,
                  let audioData = Data(base64Encoded: audioBase64) else {
                introReady = true
                return
            }

            // Play intro and enable button after playback
            walkthrough.playIntroAudio(audioData) {
                introReady = true
            }
        }
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
