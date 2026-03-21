import Speech
import AVFoundation

/// Voice-to-text using AVAudioRecorder + SFSpeechURLRecognitionRequest.
/// Avoids AVAudioEngine entirely (crashes on iOS 18 with permission timing).
/// Records audio to a temp file, then transcribes after recording stops.
@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var isAuthorized: Bool = false

    /// Called with the final transcript when speech ends.
    var onTranscriptReady: ((String) -> Void)?

    private var audioRecorder: AVAudioRecorder?
    private var silenceTimer: Task<Void, Never>?
    private var recordingURL: URL?

    private static let silenceTimeout: Duration = .seconds(10)

    private var tempFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("reef_speech.wav")
    }

    // MARK: - Authorization

    func checkExistingAuthorization() {
        let micStatus = AVAudioApplication.shared.recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = (micStatus == .granted && speechStatus == .authorized)
    }

    func requestAuthorization() async {
        let micGranted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else {
            isAuthorized = false
            return
        }

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
            stopAndTranscribe()
        } else {
            if isAuthorized {
                startRecording()
            } else {
                Task {
                    await requestAuthorization()
                }
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard isAuthorized else { return }

        // Clean up any previous recording
        stopRecording()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = tempFileURL
            // Remove old file if exists
            try? FileManager.default.removeItem(at: url)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            audioRecorder = recorder
            recordingURL = url
            isListening = true
            transcript = "Listening..."

            resetSilenceTimer()
        } catch {
            print("[Speech] Failed to start recording: \(error)")
            isListening = false
        }
    }

    private func stopRecording() {
        silenceTimer?.cancel()
        silenceTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Stop recording and transcribe the audio file.
    func stopAndTranscribe() {
        guard let url = recordingURL else {
            stopRecording()
            return
        }

        stopRecording()
        transcript = "Transcribing..."

        Task {
            await transcribeFile(at: url)
        }
    }

    // MARK: - Transcription

    private func transcribeFile(at url: URL) async {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            transcript = ""
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        do {
            let text: String = try await withCheckedThrowingContinuation { cont in
                recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        let t = result.bestTranscription.formattedString
                        cont.resume(returning: t)
                    } else if let error {
                        cont.resume(throwing: error)
                    }
                }
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            transcript = ""

            if !trimmed.isEmpty {
                onTranscriptReady?(trimmed)
            }
        } catch {
            print("[Speech] Transcription failed: \(error)")
            transcript = ""
        }

        // Cleanup temp file
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }

    // MARK: - Silence Timer

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.silenceTimeout)
            guard let self, !Task.isCancelled, self.isListening else { return }
            self.stopAndTranscribe()
        }
    }
}
