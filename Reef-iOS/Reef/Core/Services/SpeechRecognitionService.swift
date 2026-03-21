import Speech
import AVFoundation

/// On-device speech recognition with auto-stop on 10s silence.
@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var isAuthorized: Bool = false

    /// Called with the final transcript when speech ends (silence timeout or manual stop).
    var onTranscriptReady: ((String) -> Void)?

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var silenceTimer: Task<Void, Never>?
    private var hasTap: Bool = false

    private static let silenceTimeout: Duration = .seconds(10)

    // MARK: - Authorization

    func requestAuthorization() {
        AVAudioApplication.requestRecordPermission { [weak self] micGranted in
            guard micGranted else {
                Task { @MainActor in self?.isAuthorized = false }
                return
            }
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self?.isAuthorized = (status == .authorized)
                }
            }
        }
    }

    // MARK: - Toggle

    /// Returns true if listening started, false if only auth was requested.
    @discardableResult
    func toggle() -> Bool {
        if isListening {
            stopListening(sendTranscript: true)
            return false
        } else {
            return startListening()
        }
    }

    // MARK: - Start / Stop

    /// Returns true if listening actually started.
    @discardableResult
    func startListening() -> Bool {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return false
        }

        if !isAuthorized {
            requestAuthorization()
            return false
        }

        // Stop any existing session
        stopListening(sendTranscript: false)

        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            self.audioEngine = engine

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            recognitionRequest = request

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            hasTap = true

            engine.prepare()
            try engine.start()

            isListening = true

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

                    if error != nil {
                        self.stopListening(sendTranscript: !self.transcript.isEmpty)
                    }
                }
            }

            resetSilenceTimer()
            return true
        } catch {
            print("[Speech] Failed to start: \(error)")
            cleanupEngine()
            return false
        }
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
        isListening = false

        if sendTranscript, !finalTranscript.isEmpty {
            onTranscriptReady?(finalTranscript)
            transcript = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanupEngine() {
        if let engine = audioEngine {
            engine.stop()
            if hasTap {
                engine.inputNode.removeTap(onBus: 0)
                hasTap = false
            }
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
