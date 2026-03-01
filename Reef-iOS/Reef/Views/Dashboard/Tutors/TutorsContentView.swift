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

// MARK: - Main View

struct TutorsContentView: View {
    @State private var viewModel = TutorsViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                headerRow
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)

                if viewModel.isLoading {
                    skeletonCarousel
                        .padding(.top, 24)
                } else if viewModel.tutors.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    // Spotlight hero
                    if let tutor = viewModel.activeTutor {
                        TutorSpotlightView(
                            tutor: tutor,
                            isSpeaking: viewModel.speakingTutorId == tutor.id,
                            onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                            onStartSession: { /* placeholder */ }
                        )
                        .id(viewModel.activeTutorId)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .animation(.spring(duration: 0.35), value: viewModel.activeTutorId)
                        .padding(.bottom, 24)
                    }

                    // Carousel section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CHOOSE YOUR TUTOR")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(0.06 * 11)
                            .foregroundStyle(ReefColors.gray400)

                        tutorCarousel
                    }
                }
            }
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
        .overlay {
            if viewModel.showQuiz {
                TutorQuizPopup(
                    tutors: viewModel.tutors,
                    onSelectTutor: { tutor in
                        viewModel.selectTutor(tutor)
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.showQuiz = false
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.showQuiz = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tutors")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(ReefColors.black)

                Spacer()

                // Find Your Tutor quiz button
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.showQuiz = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text("Find Your Tutor")
                            .font(.epilogue(14, weight: .bold))
                            .tracking(-0.04 * 14)
                    }
                    .foregroundStyle(ReefColors.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ReefColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReefColors.black, lineWidth: 1.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ReefColors.black)
                            .offset(x: 4, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }

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
                        .frame(width: 220, height: 240)
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
