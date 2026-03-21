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
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var silenceTimer: Task<Void, Never>?

    private static let silenceTimeout: Duration = .seconds(10)

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = (status == .authorized)
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable, isAuthorized else {
            requestAuthorization()
            return
        }

        // Stop any existing session
        stopListening(sendTranscript: false)

        transcript = ""
        isListening = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("[Speech] Audio engine failed to start: \(error)")
            isListening = false
            return
        }

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
    }

    func stopListening(sendTranscript: Bool = true) {
        silenceTimer?.cancel()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        isListening = false

        if sendTranscript, !finalTranscript.isEmpty {
            onTranscriptReady?(finalTranscript)
            transcript = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggle() {
        if isListening {
            stopListening(sendTranscript: true)
        } else {
            startListening()
        }
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
