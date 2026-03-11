import SwiftUI
import AVFoundation

// MARK: - ViewModel

@Observable
@MainActor
final class TutorsViewModel {
    var tutors: [Tutor] = []
    var isLoading = true
    var selectedTutor: Tutor?
    var speakingTutorId: String?
    var showQuiz = false
    var activeTutorId: String? {
        didSet { UserDefaults.standard.set(activeTutorId, forKey: "reef_active_tutor_id") }
    }

    private let synthesizer = AVSpeechSynthesizer()

    var activeTutor: Tutor? {
        guard let id = activeTutorId else { return nil }
        return tutors.first(where: { $0.id == id })
    }

    // MARK: - Lifecycle

    func onAppear() async {
        activeTutorId = UserDefaults.standard.string(forKey: "reef_active_tutor_id")
        await fetchTutors()

        // Default to Kai if none selected
        if activeTutorId == nil {
            activeTutorId = "tutor-kai"
        }
    }

    func onDisappear() {
        stopSpeaking()
    }

    // MARK: - Fetch

    func fetchTutors() async {
        do {
            tutors = try await TutorService.shared.listTutors()
        } catch {
            print("Failed to fetch tutors: \(error)")
        }
        isLoading = false
    }

    // MARK: - Selection

    func selectTutor(_ tutor: Tutor) {
        withAnimation(.spring(duration: 0.3)) {
            activeTutorId = tutor.id
        }
    }

    // MARK: - Voice Preview

    func toggleVoicePreview(for tutor: Tutor) {
        if speakingTutorId == tutor.id {
            stopSpeaking()
        } else {
            stopSpeaking()
            let utterance = AVSpeechUtterance(string: tutor.introPhrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            speakingTutorId = tutor.id

            synthesizer.speak(utterance)

            // Monitor for completion
            Task {
                while synthesizer.isSpeaking {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                if speakingTutorId == tutor.id {
                    speakingTutorId = nil
                }
            }
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingTutorId = nil
    }
}
