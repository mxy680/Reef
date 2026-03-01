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
    var activeTutorId: String? {
        didSet { UserDefaults.standard.set(activeTutorId, forKey: "reef_active_tutor_id") }
    }

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Lifecycle

    func onAppear() async {
        activeTutorId = UserDefaults.standard.string(forKey: "reef_active_tutor_id")
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

// MARK: - Main View

struct TutorsContentView: View {
    @State private var viewModel = TutorsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            Spacer()

            if viewModel.isLoading {
                skeletonCarousel
            } else if viewModel.tutors.isEmpty {
                emptyState
            } else {
                tutorCarousel
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .dashboardCard()
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(item: $viewModel.selectedTutor) { tutor in
            TutorDetailSheet(
                tutor: tutor,
                isSpeaking: viewModel.speakingTutorId == tutor.id,
                isActive: viewModel.activeTutorId == tutor.id,
                onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                onSelect: { viewModel.selectTutor(tutor) },
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

            HStack(spacing: 10) {
                Text("Meet your AI study companions — tap a card to learn more.")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.gray600)

                if let activeId = viewModel.activeTutorId,
                   let tutor = viewModel.tutors.first(where: { $0.id == activeId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(tutor.name)
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                    }
                    .foregroundStyle(Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ReefColors.gray100)
                        .frame(width: 240, height: 380)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Carousel

    private var tutorCarousel: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(viewModel.tutors.enumerated()), id: \.element.id) { index, tutor in
                        TutorCardView(
                            tutor: tutor,
                            index: index,
                            isSpeaking: viewModel.speakingTutorId == tutor.id,
                            isActive: viewModel.activeTutorId == tutor.id,
                            onTap: { viewModel.selectedTutor = tutor },
                            onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                            onSelect: { viewModel.selectTutor(tutor) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            // Scroll hint dots
            HStack(spacing: 6) {
                ForEach(viewModel.tutors) { tutor in
                    Circle()
                        .fill(viewModel.activeTutorId == tutor.id
                              ? Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
                              : ReefColors.gray400.opacity(0.4))
                        .frame(width: viewModel.activeTutorId == tutor.id ? 8 : 6,
                               height: viewModel.activeTutorId == tutor.id ? 8 : 6)
                        .animation(.spring(duration: 0.25), value: viewModel.activeTutorId)
                }
            }
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
    }
}
