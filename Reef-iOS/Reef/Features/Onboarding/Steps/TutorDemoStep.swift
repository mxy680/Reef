import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?
    @State private var showIntro = true
    @State private var introReady = true
    @State private var introTask: Task<Void, Never>?

    private let introDisplay = "Alright, quick intro. I'm your AI tutor. I watch everything you write in real time — yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line, no awkward eye contact. Dive in — the reef's got you covered."

    private let introSpeech = "Alright, quick intro. I'm your A.I. tutor. I watch EVERYTHING you write in real time. Yes, even the messy parts. I'll walk you through problems, give hints when you're stuck, and celebrate when you nail it. No office hours line. No awkward eye contact. Dive in. The reef's got you covered."

    var body: some View {
        ZStack {
            if let canvasVM {
                CanvasView(viewModel: canvasVM, onDismiss: {
                    Task { await viewModel.deleteDemoDocument() }
                    viewModel.goNext()
                })

                // Intro dialog overlay
                if showIntro {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    introDialogView
                        .transition(.opacity)
                        .zIndex(500)
                }
            } else {
                loadingView
            }
        }
        .animation(.easeOut(duration: 0.25), value: showIntro)
        .onAppear { generateDemo() }
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
                withAnimation { showIntro = false }
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
        .onAppear { speakIntro() }
        .onDisappear { introTask?.cancel() }
    }

    // MARK: - Intro TTS

    private func speakIntro() {
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
