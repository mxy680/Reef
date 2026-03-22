import Foundation
import AVFoundation

@Observable
@MainActor
final class DemoProblemService {

    // MARK: - State

    var isGenerating = false
    var isReady = false
    var error: String?

    var questionText = ""
    var stepsOverview = ""
    var currentStepDescription = ""
    var finalAnswer = ""
    var tutorIntro = ""

    var chatMessages: [DemoChatMessage] = []
    var isSending = false

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Server URL

    private var serverURL: String {
        Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String ?? ""
    }

    // MARK: - Generate Problem

    func generateProblem(topic: String, studentType: String = "college") async {
        guard !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isGenerating = true
        error = nil

        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/ai/demo-problem") else {
            error = "Server not configured."
            isGenerating = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: String] = [
            "topic": topic,
            "student_type": studentType,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(DemoProblemResponse.self, from: data)

            questionText = result.questionText
            finalAnswer = result.finalAnswer
            tutorIntro = result.tutorIntro

            stepsOverview = result.steps.enumerated().map { i, step in
                "Step \(i + 1): \(step.description)"
            }.joined(separator: "\n")

            currentStepDescription = result.steps.first?.description ?? ""

            chatMessages = [
                DemoChatMessage(role: .tutor, text: result.tutorIntro)
            ]

            isReady = true
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Chat

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        chatMessages.append(DemoChatMessage(role: .student, text: text))
        isSending = true

        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/ai/demo-chat") else {
            chatMessages.append(DemoChatMessage(role: .tutor, text: "Hmm, something went wrong. Try again?"))
            isSending = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let history = chatMessages.map { msg in
            ["role": msg.role == .student ? "student" : "tutor", "text": msg.text]
        }

        let body: [String: Any] = [
            "user_message": text,
            "question_text": questionText,
            "steps_overview": stepsOverview,
            "current_step_description": currentStepDescription,
            "student_work": "",
            "history": history,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(DemoChatResponse.self, from: data)

            chatMessages.append(DemoChatMessage(role: .tutor, text: result.reply))

            if let audioBase64 = result.speechAudio,
               let audioData = Data(base64Encoded: audioBase64) {
                playAudio(audioData)
            }
        } catch {
            chatMessages.append(DemoChatMessage(role: .tutor, text: "Hmm, something went wrong. Try again?"))
        }

        isSending = false
    }

    // MARK: - Audio

    private func playAudio(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            // Silent failure — audio is optional
        }
    }
}

// MARK: - Models

struct DemoChatMessage: Identifiable {
    let id = UUID()
    let role: DemoChatRole
    let text: String
    let timestamp = Date()
}

enum DemoChatRole {
    case student
    case tutor
}

// MARK: - Response DTOs

private struct DemoProblemResponse: Codable {
    let questionText: String
    let steps: [DemoStep]
    let finalAnswer: String
    let tutorIntro: String

    enum CodingKeys: String, CodingKey {
        case questionText = "question_text"
        case steps
        case finalAnswer = "final_answer"
        case tutorIntro = "tutor_intro"
    }
}

private struct DemoStep: Codable {
    let description: String
    let explanation: String
    let work: String
    let reinforcement: String
}

private struct DemoChatResponse: Codable {
    let reply: String
    let speechAudio: String?

    enum CodingKeys: String, CodingKey {
        case reply
        case speechAudio = "speech_audio"
    }
}
