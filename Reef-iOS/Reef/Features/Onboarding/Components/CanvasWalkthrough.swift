import SwiftUI
import AVFoundation
@preconcurrency import Supabase

// MARK: - Walkthrough Step

enum WalkthroughStep: Int, CaseIterable {
    // Phase 1: Tool Training
    case drawSomething = 0
    case tryHighlighter
    case eraseHighlight
    case otherTools
    case utilityTools

    // Phase 2: Tutor Training
    case enableTutor
    case tutorFeatures
    case tutorUI
    case ready

    var text: String {
        switch self {
        case .drawSomething:
            "Grab your Apple Pencil and draw anything. Seriously, anything."
        case .tryHighlighter:
            "Now tap the highlighter and mark something up."
        case .eraseHighlight:
            "Now erase what you just highlighted."
        case .otherTools:
            "A few more tools:\n\n• Shape tool — draw a shape and Reef cleans it up. Great for diagrams.\n• Lasso — circle anything to select, move, or delete it.\n• Finger draw — lets you draw with your finger too."
        case .utilityTools:
            "And some handy extras:\n\n• Ruler — for straight lines.\n• Calculator — built-in, because who wants to switch apps.\n• Page settings — grid, dots, lines, or blank background."
        case .enableTutor:
            "Now let's try the AI tutor. Tap the tutor button to turn it on."
        case .tutorFeatures:
            "Your tutor gives you:\n\n• Step descriptions — what to do next.\n• 💡 Hints — tap the lightbulb when you're stuck.\n• 👁 Answers — tap to reveal the full solution."
        case .tutorUI:
            "A couple more things:\n\n• The progress bar shows how far you've solved.\n• The sidebar is where your tutor lives — steps, hints, and chat."
        case .ready:
            "That's it. Now try solving the problem. Your tutor's watching."
        }
    }

    var requiresAction: Bool {
        switch self {
        case .drawSomething, .tryHighlighter, .eraseHighlight, .enableTutor:
            return true
        default:
            return false
        }
    }

    var buttonLabel: String {
        switch self {
        case .ready: "Let's go"
        default: "Got it"
        }
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
    var debugLogs: [String] = []
    private var audioPlayer: AVAudioPlayer?

    func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        if debugLogs.count > 50 { debugLogs.removeFirst() }
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
        Task { @MainActor in
            guard let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
                  let token = try? await supabase.auth.session.accessToken else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            struct TTSResponse: Decodable {
                let speechAudio: String?
                enum CodingKeys: String, CodingKey {
                    case speechAudio = "speech_audio"
                }
            }

            guard let result = try? JSONDecoder().decode(TTSResponse.self, from: data),
                  let audioBase64 = result.speechAudio,
                  let audioData = Data(base64Encoded: audioBase64) else { return }

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
