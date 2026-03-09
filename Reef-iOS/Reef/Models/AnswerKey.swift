import Foundation

struct AnswerKeyStep: Codable, Sendable {
    let description: String
    let explanation: String
    let work: String
}

struct PartAnswer: Codable, Sendable {
    let label: String
    let steps: [AnswerKeyStep]
    let finalAnswer: String
    let parts: [PartAnswer]

    enum CodingKeys: String, CodingKey {
        case label, steps, parts
        case finalAnswer = "final_answer"
    }
}

struct QuestionAnswer: Codable, Sendable {
    let questionNumber: Int
    let steps: [AnswerKeyStep]
    let finalAnswer: String
    let parts: [PartAnswer]

    enum CodingKeys: String, CodingKey {
        case steps, parts
        case questionNumber = "question_number"
        case finalAnswer = "final_answer"
    }
}
