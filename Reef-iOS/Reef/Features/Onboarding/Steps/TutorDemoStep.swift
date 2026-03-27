import SwiftUI
import PencilKit

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    @State private var machine = WalkthroughStateMachine()
    @State private var audio = WalkthroughAudioService()
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?

    @State private var voiceMode = true
    @State private var dialogPhase: DialogPhase = .voiceChoice
    @State private var problemSolved = false
    @State private var hasNavigated = false
    @State private var autoContinueTask: Task<Void, Never>?

    @State private var introReady = true
    @State private var introTask: Task<Void, Never>?
    @State private var pendingReactionTask: Task<Void, Never>?

    // Loading card state
    @State private var isPulsing = false
    @State private var messageIndex = 0
    @State private var loadingTasks: [Task<Void, Never>] = []

    private let introDisplay = "Alright, quick intro. I'm your AI tutor. I watch everything you write in real time — yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line, no awkward eye contact. Dive in — the reef's got you covered."

    private let introSpeech = "Alright, quick intro. I'm your A.I. tutor. I watch EVERYTHING you write in real time. Yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line. No awkward eye contact. Dive in. The reef's got you covered."

    // MARK: - Dialog Phase

    enum DialogPhase {
        case voiceChoice, experience, skipTools, intro, none
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .onAppear { generateDemo() }
            .onDrawingChanged(canvasVM: canvasVM, machine: machine, audio: audio, dialogPhase: dialogPhase, reactionTask: $pendingReactionTask)
            .onToolChanged(canvasVM: canvasVM, machine: machine, dialogPhase: dialogPhase)
            .onFeatureToggled(canvasVM: canvasVM, machine: machine)
            .onTutorEvents(canvasVM: canvasVM, machine: machine, audio: audio, voiceMode: voiceMode, dialogPhase: dialogPhase, problemSolved: $problemSolved, hasNavigated: $hasNavigated, autoContinueTask: $autoContinueTask, navigateNext: navigateNext)
    }
}

// MARK: - Detection Modifiers (split for type-checker)

private extension View {
    func onDrawingChanged(canvasVM: CanvasViewModel?, machine: WalkthroughStateMachine, audio: WalkthroughAudioService, dialogPhase: TutorDemoStep.DialogPhase, reactionTask: Binding<Task<Void, Never>?>) -> some View {
        self.onChange(of: canvasVM?.drawingManager.drawingVersion) { _, _ in
            guard dialogPhase == .none else { return }
            guard let vm = canvasVM, machine.currentStep == .drawSomething else { return }
            guard vm.drawingManager.hasDrawing(for: vm.currentPageIndex) else { return }
            machine.cancelPendingAdvance()
            reactionTask.wrappedValue?.cancel()
            reactionTask.wrappedValue = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                if let image = vm.captureActiveQuestionImage() {
                    let reaction = await audio.speakReaction(imageBase64: image)
                    machine.drawingReaction = reaction
                }
                machine.unlockNextPhase()
                machine.advance()
            }
        }
    }

    func onToolChanged(canvasVM: CanvasViewModel?, machine: WalkthroughStateMachine, dialogPhase: TutorDemoStep.DialogPhase) -> some View {
        self
        .onChange(of: canvasVM?.selectedTool) { _, newTool in
            guard dialogPhase == .none, let tool = newTool else { return }
            switch tool {
            case .highlighter: machine.skipToAndAdvance(.tryHighlighter)
            case .eraser: machine.skipToAndAdvance(.eraseHighlight)
            case .shapes: machine.skipToAndAdvance(.shapeTool)
            case .lasso: machine.skipToAndAdvance(.lassoTool)
            case .handDraw: machine.skipToAndAdvance(.fingerDraw)
            default: break
            }
        }
    }

    func onFeatureToggled(canvasVM: CanvasViewModel?, machine: WalkthroughStateMachine) -> some View {
        self
        .onChange(of: canvasVM?.showRuler) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.ruler) }
        }
        .onChange(of: canvasVM?.showCalculator) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.calculator) }
        }
        .onChange(of: canvasVM?.showPageSettings) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.pageSettings) }
        }
        .onChange(of: canvasVM?.showHintPopover) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.tutorHint) }
        }
        .onChange(of: canvasVM?.showRevealPopover) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.tutorReveal) }
        }
        .onChange(of: canvasVM?.showSidebar) { _, _ in
            if let step = machine.currentStep, step.phase == .postSolve {
                machine.skipToAndAdvance(.sidebarToggle)
            }
        }
        .onChange(of: canvasVM?.showBugReport) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.bugReport) }
        }
        .onChange(of: canvasVM?.showExportPreview) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.exportFeature) }
        }
        .onChange(of: canvasVM?.isMicOn) { _, isOn in
            if isOn == true { machine.skipToAndAdvance(.voiceCommand) }
        }
    }

    func onTutorEvents(canvasVM: CanvasViewModel?, machine: WalkthroughStateMachine, audio: WalkthroughAudioService, voiceMode: Bool, dialogPhase: TutorDemoStep.DialogPhase, problemSolved: Binding<Bool>, hasNavigated: Binding<Bool>, autoContinueTask: Binding<Task<Void, Never>?>, navigateNext: @escaping () -> Void) -> some View {
        self
        .onChange(of: canvasVM?.tutorModeOn) { _, isOn in
            if isOn == true, machine.currentStep == .enableTutor {
                if let vm = canvasVM {
                    vm.showSidebar = true
                    if vm.activeQuestionLabel == nil { vm.activeQuestionLabel = "Q1a" }
                }
                withAnimation { machine.advance() }
            }
        }
        .onChange(of: canvasVM?.tutorEvalService.status) { _, status in
            guard !problemSolved.wrappedValue else { return }
            if status == "completed",
               let vm = canvasVM, vm.tutorStepCount > 0,
               vm.currentTutorStepIndex >= vm.tutorStepCount - 1 {
                problemSolved.wrappedValue = true
                machine.skipTutorial()
            }
        }
        .onChange(of: machine.isComplete) { _, complete in
            guard complete, !hasNavigated.wrappedValue else { return }
            autoContinueTask.wrappedValue = Task { @MainActor in
                if voiceMode {
                    while audio.isPlayingAudio { try? await Task.sleep(for: .milliseconds(200)) }
                }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, !hasNavigated.wrappedValue else { return }
                navigateNext()
            }
        }
        .onChange(of: machine.currentStep) { oldStep, newStep in
            guard let step = newStep else { return }
            let isDrawReaction = oldStep == .drawSomething && newStep == .tryHighlighter
            if !isDrawReaction && voiceMode {
                let speechText = step.speech
                Task { @MainActor in
                    if let vm = canvasVM { await audio.waitForTutorAudio(vm.tutorEvalService) }
                    await audio.speakInstruction(speechText)
                }
            }
            if step == .pageSettings { machine.unlockNextPhase() }
            if step == .tutorReveal { machine.unlockNextPhase() }
            if step == .solveIt { machine.unlockNextPhase() }
            if step == .enableTutor { canvasVM?.deferTutorMode = false }
            if step == .ready { machine.scheduleAdvance(ms: step.autoAdvanceDelayMs) }
        }
        .onChange(of: dialogPhase) { _, phase in
            if phase == .none, machine.currentStep == .drawSomething, voiceMode {
                Task { @MainActor in
                    await audio.speakInstruction(WalkthroughStep.drawSomething.speech)
                }
            }
        }
    }
}

// MARK: - TutorDemoStep (continued)

extension TutorDemoStep {

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            if let canvasVM {
                CanvasView(
                    viewModel: canvasVM,
                    walkthroughStep: machine.currentStep,
                    onDismiss: { navigateNext() }
                )

                dialogOverlay
                    .animation(.easeOut(duration: 0.25), value: dialogPhase)

                if dialogPhase == .none && !machine.isComplete {
                    walkthroughCardOverlay
                        .zIndex(300)
                        .transition(.opacity)
                }

                if machine.isComplete {
                    doneButton
                        .zIndex(200)
                        .transition(.opacity)
                }
            } else {
                loadingCard
            }
        }
    }

    // MARK: - Dialog Overlay

    @ViewBuilder
    private var dialogOverlay: some View {
        switch dialogPhase {
        case .voiceChoice:
            WalkthroughVoiceChoiceDialog(
                onVoiceOn: {
                    voiceMode = true
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .experience }
                },
                onVoiceOff: {
                    voiceMode = false
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .experience }
                }
            )
            .zIndex(500)
            .transition(.opacity)

        case .experience:
            WalkthroughExperienceDialog(
                onYes: {
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .skipTools }
                },
                onNo: {
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .intro }
                }
            )
            .zIndex(450)
            .transition(.opacity)

        case .skipTools:
            WalkthroughSkipToolsDialog(
                onSkip: {
                    // Skip to Phase 2 (tutor training)
                    audio.isSpeaking = true  // Ensure popup types immediately
                    machine.jumpToPhase(.tutorTraining)
                    canvasVM?.deferTutorMode = false
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .none }
                },
                onShowAll: {
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .intro }
                }
            )
            .zIndex(450)
            .transition(.opacity)

        case .intro:
            WalkthroughIntroDialog(
                introText: introDisplay,
                introReady: introReady,
                onLetsGo: {
                    withAnimation(.easeOut(duration: 0.25)) { dialogPhase = .none }
                }
            )
            .zIndex(400)
            .transition(.opacity)
            .onAppear { speakIntro() }
            .onDisappear { introTask?.cancel() }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Walkthrough Card Overlay

    private var walkthroughCardOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            WalkthroughCard(
                step: machine.currentStep,
                reactionPrefix: machine.drawingReaction,
                readyToType: voiceMode ? audio.isSpeaking : true,
                onGotIt: { machine.advance() }
            )

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: {
                    machine.skipTutorial()
                }) {
                    Text("Skip tutorial")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: {
                    machine.advance()
                }) {
                    Text("Next step →")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Done Button

    private func navigateNext() {
        guard !hasNavigated else { return }
        hasNavigated = true
        autoContinueTask?.cancel()
        Task { await viewModel.deleteDemoDocument() }
        viewModel.goNext()
    }

    private var doneButton: some View {
        VStack {
            Spacer()
            HStack {
                ReefButton(problemSolved ? "Continue →" : "Done — show me my plan", size: .compact, action: {
                    navigateNext()
                })
                .padding(20)
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Intro Audio

    private func speakIntro() {
        guard voiceMode else { return }
        introReady = false
        introTask = Task { @MainActor in
            // Enable button after fallback delay in case TTS fails
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

            audio.playIntroAudio(audioData) {
                introReady = true
            }
        }
    }

    // MARK: - Demo Generation

    private func generateDemo() {
        guard !demoService.isReady && !demoService.isGenerating else { return }
        Task {
            let topic = viewModel.answers.favoriteTopic.isEmpty
                ? "derivatives"
                : viewModel.answers.favoriteTopic
            await demoService.generateDocument(
                topic: topic,
                studentType: viewModel.answers.studentType?.rawValue ?? "college"
            )
            if let doc = demoService.demoDocument {
                viewModel.demoDocumentId = doc.id
                let vm = CanvasViewModel(document: doc)
                vm.deferTutorMode = true
                vm.tutorEvalService.isDemo = true
                canvasVM = vm
            }
        }
    }

    // MARK: - Loading Card

    var currentLoadingMessage: String {
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
