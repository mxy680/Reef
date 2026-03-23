import SwiftUI
import PencilKit

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?
    @State private var walkthrough = CanvasWalkthroughState()

    var body: some View {
        ZStack {
            if let canvasVM {
                // Full canvas experience
                CanvasView(viewModel: canvasVM, onDismiss: {
                    viewModel.goNext()
                })

                // Walkthrough — persistent card with typewriter text
                if !walkthrough.isComplete {
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()

                        // Card — always present, text changes inside
                        WalkthroughCard(
                            step: walkthrough.currentStep,
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
                    .padding(.bottom, 20)
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
        // MARK: - Walkthrough Detection (1000ms after pen lift)
        .onChange(of: canvasVM?.drawingManager.drawingVersion) { _, _ in
            guard let vm = canvasVM else { return }

            switch walkthrough.currentStep {
            case .drawSomething:
                if vm.drawingManager.hasDrawing(for: vm.currentPageIndex) {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .tryHighlighter:
                if vm.selectedTool == .highlighter && vm.drawingManager.hasDrawing(for: vm.currentPageIndex) {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            case .eraseHighlight:
                if vm.selectedTool == .eraser {
                    walkthrough.advanceAfterDelay(ms: 1000)
                }

            default:
                break
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
        .onChange(of: walkthrough.currentStep) { _, newStep in
            // When walkthrough reaches enableTutor, allow the toggle to work
            if newStep == .enableTutor {
                canvasVM?.deferTutorMode = false
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
