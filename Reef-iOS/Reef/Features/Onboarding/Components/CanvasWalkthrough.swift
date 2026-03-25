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

    /// What's displayed in the walkthrough popup card.
    var text: String {
        switch self {
        // Phase 1: Tool Training
        case .drawSomething:
            "Grab your Apple Pencil and draw something fun. Literally anything — a cat, a stick figure, whatever comes to mind."
        case .tryHighlighter:
            "Tap the highlighter tool up top. It's transparent, so it layers over your ink — great for annotating."
        case .eraseHighlight:
            "Made a mess? Good. Tap the eraser and clean it up — it removes anything you draw over."
        case .shapeTool:
            "Tap the shape tool and draw a shape freehand. Reef auto-snaps it into a clean version — circles, rectangles, triangles."
        case .lassoTool:
            "Try the lasso. Draw a loop around something — now you can drag it, scale it, or send it to the abyss."
        case .fingerDraw:
            "Don't have your Pencil handy? Tap finger draw and sketch with your finger instead — same canvas, just your fingertip."
        case .ruler:
            "Tap the ruler tool. A straight edge appears on the canvas — rotate it, position it, draw along it. No more diagrams that look like they survived a tsunami."
        case .calculator:
            "Need to check your math? Tap the calculator — it floats right on your canvas so you never lose your place."
        case .pageSettings:
            "Tap page settings to change your canvas background. Graph paper for plotting, dot grid for diagrams, lined for notes — pick whatever helps you think."
        // Phase 2: Tutor Training
        case .enableTutor:
            "Here's what makes Reef different. Tap the tutor toggle — your AI reads your handwriting live, knows the answer key, and coaches you without giving it away."
        case .tutorHint:
            "That lightbulb is your hint button. Tap it when you're stuck — your tutor gives you a push without spoiling the answer. Training wheels, not a cheat code."
        case .tutorReveal:
            "Tap the eye icon to reveal the full solution for this step. Sometimes you just need to see how it's done — no judgment."
        // Phase 3: Solve It
        case .solveIt:
            "OK dive in. Work through the problem step by step — your tutor reads your handwriting in real time and jumps in when you need a hand."
        // Phase 4: Post-Solve
        case .voiceCommand:
            "Tap the mic to talk to your tutor. Ask a question about the problem, or just chat — it's like office hours but you don't have to leave your desk."
        case .sidebarToggle:
            "Need more canvas space? Tap the sidebar icon to hide the tutor panel. Tap it again to bring it back when you want help."
        case .bugReport:
            "See the bug icon? That's your direct line to us. If something's off, let us know — we read every single report. Seriously."
        case .exportFeature:
            "Tap export to save your canvas as a PDF — drawings, annotations, everything. Perfect for submitting homework or saving your notes."
        case .ready:
            "That's everything. You know the tools, you've met your tutor, and you crushed a problem. Now go dive in for real."
        }
    }

    /// TTS-optimized version with full sentences, emphasis, and precise punctuation for Orpheus voice model.
    var speech: String {
        switch self {
        // Phase 1: Tool Training
        case .drawSomething:
            "Grab your Apple Pencil, and draw something fun. LITERALLY anything. A cat, a stick figure, whatever comes to mind."
        case .tryHighlighter:
            "Now tap the highlighter tool, up at the top. It's transparent, so it layers RIGHT over your ink. It's great for annotating your work."
        case .eraseHighlight:
            "Made a mess? GOOD. Now tap the eraser, and clean it up. It removes ANYTHING you draw over."
        case .shapeTool:
            "Tap the shape tool, and draw a shape freehand. Reef will AUTO-SNAP it into a clean version. Circles, rectangles, and triangles."
        case .lassoTool:
            "Now try the lasso tool. Draw a loop around something you drew. Now you can DRAG it, SCALE it, or send it straight to the abyss."
        case .fingerDraw:
            "Don't have your Pencil handy? Tap the finger draw tool, and sketch with your finger instead. Same canvas, just your fingertip."
        case .ruler:
            "Tap the ruler tool. A straight edge will appear on the canvas. You can rotate it, position it, and draw along it. No more diagrams that look like they survived a TSUNAMI."
        case .calculator:
            "Need to check your math? Tap the calculator. It floats RIGHT on your canvas, so you NEVER lose your place."
        case .pageSettings:
            "Tap page settings to change your canvas background. Graph paper for plotting. Dot grid for diagrams. Lined for notes. Pick whatever helps you think."
        // Phase 2: Tutor Training
        case .enableTutor:
            "HERE is what makes Reef different. Tap the tutor toggle. Your A.I. reads your handwriting LIVE, knows the answer key, and coaches you, without giving it away."
        case .tutorHint:
            "THAT lightbulb, is your hint button. Tap it when you're stuck. Your tutor will give you a push, WITHOUT spoiling the answer. Training wheels, NOT a cheat code."
        case .tutorReveal:
            "Tap the eye icon, to reveal the FULL solution for this step. Sometimes, you just need to see how it's done. No judgment."
        // Phase 3: Solve It
        case .solveIt:
            "OK, DIVE IN. Work through the problem, step by step. Your tutor reads your handwriting in REAL time, and will jump in when you need a hand."
        // Phase 4: Post-Solve
        case .voiceCommand:
            "Tap the mic, to talk to your tutor. Ask a question about the problem, or just CHAT. It's like office hours, but you don't have to leave your desk."
        case .sidebarToggle:
            "Need more canvas space? Tap the sidebar icon, to HIDE the tutor panel. Tap it again, to bring it back when you want help."
        case .bugReport:
            "See the bug icon? That is your DIRECT line to us. If something's off, let us know. We read EVERY single report. Seriously."
        case .exportFeature:
            "Tap export, to save your canvas as a P.D.F. Drawings, annotations, EVERYTHING. Perfect for submitting homework, or saving your notes."
        case .ready:
            "That's EVERYTHING. You know the tools, you've met your tutor, and you CRUSHED a problem. Now, go dive in for real."
        }
    }

    var requiresAction: Bool {
        true
    }

    var buttonLabel: String {
        ""
    }

    /// Which drawing tool this step targets (for glow highlight).
    var targetDrawingTool: CanvasToolType? {
        switch self {
        case .tryHighlighter: .highlighter
        case .eraseHighlight: .eraser
        case .shapeTool: .shapes
        case .lassoTool: .lasso
        case .fingerDraw: .handDraw
        default: nil
        }
    }

    /// Which utility/right-side button this step targets (for glow highlight).
    enum TargetButton: String {
        case ruler, calculator, pageSettings
        case mic, sidebar, bugReport, export
        case tutorToggle, hint, reveal
    }

    var targetButton: TargetButton? {
        switch self {
        case .ruler: .ruler
        case .calculator: .calculator
        case .pageSettings: .pageSettings
        case .enableTutor: .tutorToggle
        case .tutorHint: .hint
        case .tutorReveal: .reveal
        case .voiceCommand: .mic
        case .sidebarToggle: .sidebar
        case .bugReport: .bugReport
        case .exportFeature: .export
        default: nil
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
            // Wait for walkthrough TTS to finish before advancing
            while isPlayingAudio {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
            }
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

    func restart() {
        pendingAdvanceTask?.cancel()
        isSpeaking = false
        isPlayingAudio = false
        isComplete = false
        drawingReaction = nil
        waitingForReaction = false
        currentStep = .drawSomething
    }

    // MARK: - Drawing Reaction

    var drawingReaction: String?
    var waitingForReaction = false
    var isSpeaking = false  // True once TTS audio starts playing for current step
    var isPlayingAudio = false  // True while audio is actively playing
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: WalkthroughAudioDelegate?

    /// Play intro audio with a completion callback (for enabling the "Let's go" button).
    func playIntroAudio(_ data: Data, onFinish: @escaping () -> Void) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: data)
            let delegate = WalkthroughAudioDelegate {
                Task { @MainActor in onFinish() }
            }
            player.delegate = delegate
            audioDelegate = delegate
            audioPlayer = player
            player.play()
        } catch {
            onFinish()
        }
    }

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

                // Speak reaction + next step together, then advance after TTS completes
                let allSteps = WalkthroughStep.allCases
                if let idx = allSteps.firstIndex(of: .drawSomething), idx + 1 < allSteps.count {
                    let nextStep = allSteps[idx + 1]
                    let combined = decoded.reaction + " " + nextStep.speech
                    log("Speaking combined: \(combined.prefix(80))...")
                    speakInstruction(combined)
                }
            }

            waitingForReaction = false
            // Advance after a delay to let TTS start (advance resets isSpeaking)
            advanceAfterDelay(ms: 500)
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
            let player = try AVAudioPlayer(data: data)
            let delegate = WalkthroughAudioDelegate { [weak self] in
                Task { @MainActor in
                    self?.isPlayingAudio = false
                }
            }
            player.delegate = delegate
            audioDelegate = delegate
            audioPlayer = player
            isPlayingAudio = true
            player.play()
        } catch {
            isPlayingAudio = false
        }
    }
}

// MARK: - Audio Delegate

private final class WalkthroughAudioDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish()
    }
}
