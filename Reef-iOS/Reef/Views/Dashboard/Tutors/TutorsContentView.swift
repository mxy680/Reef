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

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Lifecycle

    func onAppear() async {
        await fetchTutors()
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
                // Poll briefly — AVSpeechSynthesizer has no async API
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

// MARK: - Main View

struct TutorsContentView: View {
    @State private var viewModel = TutorsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if viewModel.isLoading {
                skeletonCarousel
            } else if viewModel.tutors.isEmpty {
                emptyState
            } else {
                tutorCarousel
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(item: $viewModel.selectedTutor) { tutor in
            TutorDetailSheet(
                tutor: tutor,
                isSpeaking: viewModel.speakingTutorId == tutor.id,
                onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                onClose: { viewModel.selectedTutor = nil }
            )
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tutors")
                .font(.epilogue(24, weight: .black))
                .tracking(-0.04 * 24)
                .foregroundStyle(ReefColors.black)

            Text("Meet your AI study companions — each with a unique teaching style and personality.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
        }
    }

    // MARK: - Skeleton

    private var skeletonCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ReefColors.gray100)
                        .frame(width: 260, height: 360)
                }
            }
        }
    }

    // MARK: - Carousel

    private var tutorCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(viewModel.tutors.enumerated()), id: \.element.id) { index, tutor in
                    TutorCardView(
                        tutor: tutor,
                        index: index,
                        isSpeaking: viewModel.speakingTutorId == tutor.id,
                        onTap: { viewModel.selectedTutor = tutor },
                        onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) }
                    )
                }
            }
            .padding(.bottom, 8) // Room for offset shadow
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No tutors available")
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(ReefColors.gray600)

            Text("Check back soon — new tutors are on the way!")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 40)
    }
}
