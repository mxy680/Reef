import Foundation

struct AnswerKeyStep: Codable, Sendable {
    let description: String
    let explanation: String
    let workedExample: String?
    let work: String
    let reinforcement: String?
    let tutorSpeech: String?
    let concepts: [String]?

    enum CodingKeys: String, CodingKey {
        case description, explanation, work, reinforcement, concepts
        case workedExample = "worked_example"
        case tutorSpeech = "tutor_speech"
    }
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

struct QuestionData: Codable, Sendable {
    let number: Int
    let text: String
    let parts: [QuestionPart]

    struct QuestionPart: Codable, Sendable {
        let label: String
        let text: String
        let parts: [QuestionPart]
    }

    /// Returns the question stem + the matching part's text for a given label.
    /// Searches recursively through nested parts.
    func textForPart(_ label: String) -> String {
        var result = text
        if let partText = findPartText(label, in: parts) {
            if !result.isEmpty { result += "\n\n" }
            result += partText
        }
        return result
    }

    private func findPartText(_ label: String, in parts: [QuestionPart]) -> String? {
        for part in parts {
            if part.label == label { return part.text }
            if let found = findPartText(label, in: part.parts) { return found }
        }
        return nil
    }
}
