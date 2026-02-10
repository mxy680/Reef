//
//  TutorAudioPlayer.swift
//  Reef
//
//  AVAudioPlayer-based playback for AI tutor voice feedback.
//  Plays complete WAV blobs with rate limiting and queue management.
//

import Foundation
import AVFoundation

@MainActor
final class TutorAudioPlayer: ObservableObject {

    // MARK: - State

    private var audioPlayer: AVAudioPlayer?
    private var queue: [(Data, String)] = []  // (audioData, feedbackText)
    @Published private(set) var isPlaying: Bool = false

    // MARK: - Public Methods

    /// Enqueue audio for playback.
    func enqueue(audioData: Data, text: String) {
        if !isPlaying {
            play(audioData: audioData, text: text)
        } else {
            queue.append((audioData, text))
            print("[TutorAudio] Queued: \(text.prefix(50))")
        }
    }

    /// Cancel all playback and clear queue.
    func cancelAll() {
        queue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        AudioPlayerDelegate.shared.onFinished = nil
        isPlaying = false
        deactivateAudioSession()
        print("[TutorAudio] Cancelled all")
    }

    // MARK: - Private

    private func play(audioData: Data, text: String) {
        do {
            configureAudioSession()

            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            AudioPlayerDelegate.shared.onFinished = { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackFinished()
                }
            }
            audioPlayer?.play()
            isPlaying = true
            print("[TutorAudio] Playing: \(text.prefix(50))")
        } catch {
            print("[TutorAudio] Playback error: \(error.localizedDescription)")
            isPlaying = false
            playNext()
        }
    }

    private func handlePlaybackFinished() {
        isPlaying = false
        audioPlayer = nil
        deactivateAudioSession()
        playNext()
    }

    private func playNext() {
        guard !queue.isEmpty else { return }
        let (data, text) = queue.removeFirst()
        play(audioData: data, text: text)
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("[TutorAudio] Audio session config error: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical — other audio will resume automatically
        }
    }
}

// MARK: - AVAudioPlayerDelegate (NSObject required)

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[TutorAudio] Decode error: \(error?.localizedDescription ?? "unknown")")
        onFinished?()
    }
}
