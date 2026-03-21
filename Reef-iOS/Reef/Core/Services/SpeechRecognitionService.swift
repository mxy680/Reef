import Speech
import AVFoundation

/// On-device speech recognition with auto-stop on 10s silence.
/// Key safety rules for iOS 18:
/// - SFSpeechRecognizer must be created lazily (after auth)
/// - AVAudioSession category must be set BEFORE creating AVAudioEngine
/// - Permission requests must be serial, not nested
/// - AVAudioEngine must be created fresh each session
@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var isAuthorized: Bool = false

    /// Called with the final transcript when speech ends.
    var onTranscriptReady: ((String) -> Void)?

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine: AVAudioEngine?
    private var silenceTimer: Task<Void, Never>?
    private var hasTap: Bool = false

    private static let silenceTimeout: Duration = .seconds(10)

    // MARK: - Authorization

    /// Request mic + speech permissions serially. Call from mic button tap.
    func requestAuthorization() async {
        // Step 1: Mic permission
        let micGranted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else {
            isAuthorized = false
            return
        }

        // Step 2: Speech permission (serial, not nested)
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        isAuthorized = (speechStatus == .authorized)
    }

    // MARK: - Toggle

    func toggle() {
        if isListening {
            stopListening(sendTranscript: true)
        } else {
            if isAuthorized {
                startListening()
            } else {
                Task {
                    await requestAuthorization()
                    // Don't auto-start — user taps again
                }
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard isAuthorized else { return }

        // Create recognizer lazily (after auth confirmed)
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            return
        }

        stopListening(sendTranscript: false)
        transcript = ""

        // 1. Configure audio session BEFORE creating engine
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[Speech] Audio session setup failed: \(error)")
            return
        }

        // 2. Create engine AFTER audio session is active
        let engine = AVAudioEngine()
        self.audioEngine = engine

        // 3. Set up recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        // 4. Install tap and start engine
        do {
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                print("[Speech] Invalid recording format (sampleRate=0)")
                cleanupEngine()
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            hasTap = true

            engine.prepare()
            try engine.start()
        } catch {
            print("[Speech] Engine start failed: \(error)")
            cleanupEngine()
            return
        }

        isListening = true

        // 5. Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.stopListening(sendTranscript: true)
                    }
                }

                if error != nil, !self.transcript.isEmpty {
                    self.stopListening(sendTranscript: true)
                } else if error != nil {
                    self.stopListening(sendTranscript: false)
                }
            }
        }

        resetSilenceTimer()
    }

    func stopListening(sendTranscript: Bool = true) {
        silenceTimer?.cancel()
        silenceTimer = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        cleanupEngine()

        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasListening = isListening
        isListening = false

        if sendTranscript, wasListening, !finalTranscript.isEmpty {
            onTranscriptReady?(finalTranscript)
            transcript = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanupEngine() {
        guard let engine = audioEngine else { return }
        engine.stop()
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        audioEngine = nil
    }

    // MARK: - Silence Timer

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.silenceTimeout)
            guard let self, !Task.isCancelled, self.isListening else { return }
            self.stopListening(sendTranscript: true)
        }
    }
}
