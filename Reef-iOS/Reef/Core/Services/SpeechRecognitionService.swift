import AVFoundation
@preconcurrency import Supabase

/// Voice-to-text using AVAudioRecorder + server-side Whisper transcription.
/// Avoids SFSpeechRecognizer/AVAudioEngine (crash on iOS 18).
@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var isAuthorized: Bool = false
    var onTranscriptReady: ((String) -> Void)?

    private var audioRecorder: AVAudioRecorder?
    private var silenceTimer: Task<Void, Never>?

    private static let silenceTimeout: Duration = .seconds(10)

    private var tempFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("reef_speech.m4a")
    }

    // MARK: - Toggle

    func toggle() {
        if isListening {
            stopAndTranscribe()
        } else {
            if isAuthorized {
                startRecording()
            } else {
                Task { await requestMicPermission() }
            }
        }
    }

    // MARK: - Permission (mic only — no Speech framework)

    private func requestMicPermission() async {
        let granted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        isAuthorized = granted
    }

    // MARK: - Recording

    private func startRecording() {
        stopRecording()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = tempFileURL
            try? FileManager.default.removeItem(at: url)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            audioRecorder = recorder
            isListening = true
            transcript = "Listening..."

            resetSilenceTimer()
        } catch {
            print("[Speech] Recording failed: \(error)")
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

    func stopAndTranscribe() {
        let url = tempFileURL
        stopRecording()

        guard FileManager.default.fileExists(atPath: url.path) else {
            transcript = ""
            return
        }

        transcript = "Transcribing..."

        Task {
            do {
                let text = try await transcribeViaServer(fileURL: url)
                transcript = ""
                if !text.isEmpty {
                    onTranscriptReady?(text)
                }
            } catch {
                print("[Speech] Server transcription failed: \(error)")
                transcript = ""
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Server Transcription

    private func transcribeViaServer(fileURL: URL) async throws -> String {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/transcribe-audio") else {
            throw URLError(.badURL)
        }

        let audioData = try Data(contentsOf: fileURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let authSession = try await supabase.auth.session
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct TranscribeResponse: Decodable { let text: String }
        return try JSONDecoder().decode(TranscribeResponse.self, from: data).text
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
