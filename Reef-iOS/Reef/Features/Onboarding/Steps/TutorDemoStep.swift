import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?
    @State private var showVoiceChoice = true
    @State private var voiceMode = true
    @State private var showIntro = false
    @State private var introReady = true
    @State private var introTask: Task<Void, Never>?
    @State private var currentStep: Int = 0
    @State private var showWalkthrough = false

    private let introDisplay = "Alright, quick intro. I'm your AI tutor. I watch everything you write in real time — yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line, no awkward eye contact. Dive in — the reef's got you covered."

    private let introSpeech = "Alright, quick intro. I'm your A.I. tutor. I watch EVERYTHING you write in real time. Yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line. No awkward eye contact. Dive in. The reef's got you covered."

    private let walkthroughSteps = [
        "Don't worry about the question on your screen yet — we'll get to that. First, grab your Apple Pencil and draw something fun. Literally anything — a cat, a stick figure, whatever comes to mind.",
        "Tap the highlighter tool up top. It's transparent, so it layers over your ink — great for annotating.",
        "Made a mess? Good. Tap the eraser and clean it up — it removes anything you draw over.",
        "The shape tool turns your rough sketches into clean geometry — draw it ugly, Reef makes it pretty. Always use this for diagrams though. Your tutor needs to know what's math and what's art, and honestly? It can't always tell.",
        "Try the lasso. Draw a loop around something — now you can drag it, scale it, or send it to the abyss.",
        "Don't have your Pencil handy? Tap finger draw and sketch with your finger instead — same canvas, just your fingertip.",
        "Tap the ruler tool. A straight edge appears on the canvas — rotate it, position it, draw along it. No more diagrams that look like they survived a tsunami.",
        "Need to check your math? Tap the calculator — it floats right on your canvas so you never lose your place.",
        "Tap page settings to change your canvas background. Graph paper for plotting, dot grid for diagrams, lined for notes — pick whatever helps you think.",
        "Here's what makes Reef different. Tap the tutor toggle — your AI reads your handwriting live, knows the answer key, and coaches you without giving it away.",
        "See the Hint section in the sidebar? Tap it to expand — your tutor gives you a nudge without spoiling the answer. Training wheels, not a cheat code.",
        "Now tap Full Solution in the sidebar — it shows the complete work for this step. Sometimes you just need to see how it's done. No judgment.",
        "Now try solving the problem on your own. Work through it step by step — your tutor is watching and will help if you get stuck.",
    ]

    var body: some View {
        ZStack {
            if let canvasVM {
                CanvasView(viewModel: canvasVM, onDismiss: {
                    Task { await viewModel.deleteDemoDocument() }
                    viewModel.goNext()
                })

                // Voice choice overlay
                if showVoiceChoice {
                    voiceChoiceView
                        .transition(.opacity)
                        .zIndex(600)
                }

                // Intro dialog overlay
                if showIntro {
                    introDialogView
                        .transition(.opacity)
                        .zIndex(500)
                }

                // Walkthrough step popup
                if showWalkthrough && !showIntro && currentStep < walkthroughSteps.count {
                    walkthroughPopup
                        .zIndex(400)
                        .transition(.opacity)
                }
            } else {
                loadingView
            }
        }
        .animation(.easeOut(duration: 0.25), value: showVoiceChoice)
        .animation(.easeOut(duration: 0.25), value: showIntro)
        .animation(.easeOut(duration: 0.25), value: showWalkthrough)
        .animation(.easeOut(duration: 0.25), value: currentStep)
        .onAppear { generateDemo() }
    }

    // MARK: - Voice Choice

    private var voiceChoiceView: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text("How would you like your tutor to communicate?")
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
                    withAnimation {
                        showVoiceChoice = false
                        showIntro = true
                    }
                }) {
                    Text("🔊 Voice mode")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: {
                    voiceMode = false
                    withAnimation {
                        showVoiceChoice = false
                        showIntro = true
                    }
                }) {
                    Text("📝 Text only")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Intro Dialog

    private var introDialogView: some View {
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
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 14).fill(colors.shadow).offset(x: 3, y: 3))

            ReefButton(.primary, size: .compact, action: {
                introTask?.cancel()
                withAnimation {
                    showIntro = false
                    showWalkthrough = true
                }
            }) {
                Text("Let's go")
                    .font(.epilogue(11, weight: .bold))
                    .tracking(-0.04 * 11)
            }
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .onAppear { speakIntro() }
        .onDisappear { introTask?.cancel() }
    }

    // MARK: - Walkthrough Popup

    private var walkthroughPopup: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 8) {
            Spacer()

            // Step text card
            Text(walkthroughSteps[currentStep])
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
                .id(currentStep)  // force re-render on step change

            // Buttons
            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: {
                    Task { await viewModel.deleteDemoDocument() }
                    viewModel.goNext()
                }) {
                    Text("Skip tutorial")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: {
                    withAnimation {
                        if currentStep < walkthroughSteps.count - 1 {
                            currentStep += 1
                        } else {
                            showWalkthrough = false
                        }
                    }
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

    // MARK: - Intro TTS

    private func speakIntro() {
        guard voiceMode else { introReady = true; return }
        introReady = false
        introTask = Task { @MainActor in
            // Fallback: enable button after 3s in case TTS fails
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

            // Play audio, enable button when done
            canvasVM?.tutorEvalService.playAudio(audioData)
            // Wait for audio to finish
            while canvasVM?.tutorEvalService.isTutorSpeaking == true {
                try? await Task.sleep(for: .milliseconds(200))
            }
            introReady = true
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
                vm.deferTutorMode = true  // tutor off and disabled
                vm.tutorEvalService.isDemo = true
                canvasVM = vm
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        let colors = theme.colors
        return VStack(spacing: 20) {
            if demoService.isGenerating {
                ProgressView()
                    .tint(colors.text)
                Text("Generating a problem for you...")
                    .font(.epilogue(16, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            } else if let error = demoService.error {
                Text(error)
                    .font(.epilogue(14, weight: .medium))
                    .foregroundStyle(colors.textMuted)
                ReefButton("Try again", size: .compact, action: {
                    demoService.error = nil
                    generateDemo()
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
