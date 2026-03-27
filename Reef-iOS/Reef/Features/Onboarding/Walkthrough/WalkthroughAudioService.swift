import AVFoundation
@preconcurrency import Supabase

// MARK: - Walkthrough Audio Service

@Observable
@MainActor
final class WalkthroughAudioService {
    var isSpeaking = false
    var isPlayingAudio = false

    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: WalkthroughAudioPlayerDelegate?

    private var serverURL: String {
        Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String ?? ""
    }

    // MARK: - Public API

    /// Fetch TTS for the given text and play it, waiting until playback finishes.
    func speakInstruction(_ text: String) async {
        guard !text.isEmpty else { return }
        isSpeaking = true
        guard let audioData = await fetchTTS(text: text) else { return }
        await playAndWait(audioData)
    }

    /// Send an image to the reaction endpoint, play the audio, and return the reaction text.
    func speakReaction(imageBase64: String) async -> String? {
        guard let url = URL(string: "\(serverURL)/ai/walkthrough-react"),
              let token = try? await supabase.auth.session.accessToken else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["image": imageBase64])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        struct ReactResponse: Decodable {
            let reaction: String
            let speechAudio: String?
            enum CodingKeys: String, CodingKey {
                case reaction
                case speechAudio = "speech_audio"
            }
        }

        guard let decoded = try? JSONDecoder().decode(ReactResponse.self, from: data) else {
            return nil
        }

        if let audioBase64 = decoded.speechAudio,
           let audioData = Data(base64Encoded: audioBase64) {
            isSpeaking = true
            await playAndWait(audioData)
        }

        return decoded.reaction
    }

    /// Play intro audio, calling onFinish when playback completes.
    func playIntroAudio(_ data: Data, onFinish: @escaping @MainActor () -> Void) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: data)
            let delegate = WalkthroughAudioPlayerDelegate {
                Task { @MainActor in onFinish() }
            }
            player.delegate = delegate
            audioDelegate = delegate
            audioPlayer = player
            isPlayingAudio = true
            player.play()
        } catch {
            onFinish()
        }
    }

    /// Wait for any active tutor audio to finish (15-second max timeout).
    func waitForTutorAudio(_ evalService: TutorEvaluationService) async {
        var waited = 0
        while evalService.isTutorSpeaking && waited < 75 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 1
        }
        try? await Task.sleep(for: .milliseconds(500))
    }

    func stopAll() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        isPlayingAudio = false
    }

    // MARK: - Private Helpers

    private func fetchTTS(text: String) async -> Data? {
        guard let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
              let token = try? await supabase.auth.session.accessToken else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
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
            return nil
        }

        return audioData
    }

    private func playAndWait(_ data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(data: data)
                let delegate = WalkthroughAudioPlayerDelegate { [weak self] in
                    Task { @MainActor in
                        self?.isPlayingAudio = false
                        cont.resume()
                    }
                }
                player.delegate = delegate
                audioDelegate = delegate
                audioPlayer = player
                isPlayingAudio = true
                player.play()
            } catch {
                isPlayingAudio = false
                cont.resume()
            }
        }
        isSpeaking = false
    }
}

// MARK: - Audio Delegate

private final class WalkthroughAudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish()
    }
}
