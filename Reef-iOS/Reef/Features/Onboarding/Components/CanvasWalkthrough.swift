import SwiftUI
import AVFoundation
@preconcurrency import Supabase

// MARK: - Walkthrough Step

enum WalkthroughStep: Int, CaseIterable {
    // Phase 1: Tool Training
    case drawSomething = 0
    case tryHighlighter
    case eraseHighlight
    case shapeTool
    case lassoTool
    case fingerDraw
    case ruler
    case calculator
    case pageSettings

    // Phase 2: Tutor Training
    case enableTutor
    case tutorHint
    case tutorReveal

    // Phase 3: Solve the problem (user works freely)
    case solveIt

    // Phase 4: After solving — remaining features
    case voiceCommand
    case sidebarToggle
    case bugReport
    case exportFeature
    case ready

    var text: String {
        switch self {
        // Phase 1: Tool Training
        case .drawSomething:
            "Pick up your Pencil and doodle something. Let's see what you got."
        case .tryHighlighter:
            "Look up at the toolbar, switch to the highlighter and scribble over something."
        case .eraseHighlight:
            "Now grab the eraser and clean that up."
        case .shapeTool:
            "Let's try the shape tool. This is how you'll draw every diagram in Reef."
        case .lassoTool:
            "The lasso tool will let you grab things. Circle a drawing, then tap it to move or trash it."
        case .fingerDraw:
            "Want to draw without your Pencil? Tap the next tool and use your finger."
        case .ruler:
            "Tap the ruler. Makes your lines not look like they were drawn during an earthquake."
        case .calculator:
            "Need to do some quick math? Tap the calculator."
        case .pageSettings:
            "Want graph paper? Tap page settings and pick your background."
        // Phase 2: Tutor Training
        case .enableTutor:
            "Here's where it gets interesting. Tap the tutor button to wake up your AI."
        case .tutorHint:
            "See the lightbulb on the top right? That's your lifeline. Tap it when you're stuck and it'll nudge you forward."
        case .tutorReveal:
            "Want the full answer? Tap the eye icon. We won't tell anyone."
        // Phase 3: Solve It
        case .solveIt:
            "Your turn. Solve the problem — your tutor's watching and will jump in if you need help."
        // Phase 4: Post-Solve
        case .voiceCommand:
            "See the mic? Tap it and just talk. Ask your tutor anything — no typing required."
        case .sidebarToggle:
            "Need more room to work? Click the sidebar icon on the right."
        case .bugReport:
            "Found a bug? Tap this icon to report it. We actually fix these."
        case .exportFeature:
            "Tap export to save your work as a PDF. Perfect for submitting homework."
        case .ready:
            "You're all set. Now go make your tutor proud."
        }
    }

    var requiresAction: Bool {
        true
    }

    var buttonLabel: String {
        ""
    }
}

// MARK: - Walkthrough State Machine

@Observable
@MainActor
final class CanvasWalkthroughState {
    var currentStep: WalkthroughStep? = .drawSomething
    var isComplete = false

    private var pendingAdvanceTask: Task<Void, Never>?

    func advance() {
        guard let current = currentStep else {
            log("advance() called but no current step")
            return
        }
        pendingAdvanceTask?.cancel()
        isSpeaking = false
        log("advance() from \(current)")

        let allSteps = WalkthroughStep.allCases
        if let idx = allSteps.firstIndex(of: current), idx + 1 < allSteps.count {
            currentStep = allSteps[idx + 1]
        } else {
            currentStep = nil
            isComplete = true
        }
    }

    func advanceAfterDelay(ms: Int) {
        pendingAdvanceTask?.cancel()
        log("advanceAfterDelay(\(ms)ms) queued")
        pendingAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ms))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    func cancelPendingAdvance() {
        pendingAdvanceTask?.cancel()
    }

    func skip() {
        pendingAdvanceTask?.cancel()
        currentStep = nil
        isComplete = true
    }

    // MARK: - Drawing Reaction

    var drawingReaction: String?
    var waitingForReaction = false
    var isSpeaking = false  // True once TTS audio starts playing for current step
    private var audioPlayer: AVAudioPlayer?

    func log(_ message: String) {
        print("[Walkthrough] \(message)")
    }

    private var serverURL: String {
        Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String ?? ""
    }

    /// Send an image of what the user drew, get a funny reaction, then advance with combined text.
    func reactToDrawing(imageBase64: String) {
        waitingForReaction = true
        log("reactToDrawing() — sending image (\(imageBase64.count) chars)")
        Task { @MainActor in
            guard let url = URL(string: "\(serverURL)/ai/walkthrough-react"),
                  let token = try? await supabase.auth.session.accessToken else {
                log("reactToDrawing() — no URL or token, skipping")
                waitingForReaction = false
                advance()
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 20
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["image": imageBase64])

            let result: (Data, URLResponse)
            do {
                result = try await URLSession.shared.data(for: request)
            } catch {
                log("reactToDrawing() — network error: \(error.localizedDescription)")
                waitingForReaction = false
                advance()
                return
            }
            let (data, resp) = result
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                log("reactToDrawing() — server returned \(code)")
                if let body = String(data: data, encoding: .utf8) {
                    log("  body: \(body.prefix(200))")
                }
                waitingForReaction = false
                advance()
                return
            }

            struct ReactResponse: Decodable {
                let reaction: String
                let speechAudio: String?
                enum CodingKeys: String, CodingKey {
                    case reaction
                    case speechAudio = "speech_audio"
                }
            }

            if let decoded = try? JSONDecoder().decode(ReactResponse.self, from: data) {
                log("reactToDrawing() — got reaction: \(decoded.reaction)")
                drawingReaction = decoded.reaction

                // Speak reaction + next step together
                if let nextStep = WalkthroughStep(rawValue: WalkthroughStep.drawSomething.rawValue + 1) {
                    let stepText = nextStep.text
                        .replacingOccurrences(of: "• ", with: "")
                        .replacingOccurrences(of: "\n\n", with: ". ")
                        .replacingOccurrences(of: "\n", with: ". ")
                    let combined = decoded.reaction + " " + stepText
                    log("Speaking combined: \(combined.prefix(80))...")
                    speakInstruction(combined)
                } else if let audioBase64 = decoded.speechAudio,
                          let audioData = Data(base64Encoded: audioBase64) {
                    playAudio(audioData)
                }
            }

            waitingForReaction = false
            advance()
        }
    }

    /// Generate TTS for a walkthrough step instruction.
    func speakInstruction(_ text: String) {
        log("speakInstruction: \(text.prefix(60))...")
        Task { @MainActor in
            guard let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
                  let token = try? await supabase.auth.session.accessToken else {
                log("speakInstruction: no URL/token, setting isSpeaking=true anyway")
                isSpeaking = true
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                log("speakInstruction: TTS request failed")
                isSpeaking = true
                return
            }

            struct TTSResponse: Decodable {
                let speechAudio: String?
                enum CodingKeys: String, CodingKey {
                    case speechAudio = "speech_audio"
                }
            }

            guard let result = try? JSONDecoder().decode(TTSResponse.self, from: data),
                  let audioBase64 = result.speechAudio,
                  let audioData = Data(base64Encoded: audioBase64) else {
                log("speakInstruction: decode failed")
                isSpeaking = true
                return
            }

            log("speakInstruction: playing audio, setting isSpeaking=true")
            isSpeaking = true
            playAudio(audioData)
        }
    }

    private func playAudio(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            // Silent failure
        }
    }
}
