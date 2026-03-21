import Foundation

/// Stub speech service — mic feature disabled until crash is resolved.
@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var isAuthorized: Bool = false
    var onTranscriptReady: ((String) -> Void)?

    func toggle() {
        // Disabled — no-op
    }
}
