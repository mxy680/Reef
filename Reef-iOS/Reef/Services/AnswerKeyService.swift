import Foundation
@preconcurrency import Supabase

/// Row shape returned from the `answer_keys` table.
private struct AnswerKeyRow: Codable {
    let documentId: String
    let questionNumber: Int
    let answerText: String
    let questionJson: QuestionData?

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case questionNumber = "question_number"
        case answerText = "answer_text"
        case questionJson = "question_json"
    }
}

struct AnswerKeyResult {
    let answers: [Int: QuestionAnswer]
    let questions: [Int: QuestionData]
}

actor AnswerKeyService {
    static let shared = AnswerKeyService()

    /// In-memory cache keyed by document ID.
    private var cache: [String: AnswerKeyResult] = [:]

    /// Fetch answer keys for a document, returning both answer and question data
    /// dictionaries keyed by question number (1-based).
    func fetchAnswerKeys(documentId: String) async -> AnswerKeyResult {
        if let cached = cache[documentId] { return cached }

        do {
            let rows: [AnswerKeyRow] = try await supabase
                .from("answer_keys")
                .select("document_id, question_number, answer_text, question_json")
                .eq("document_id", value: documentId)
                .execute()
                .value

            let decoder = JSONDecoder()
            var answers: [Int: QuestionAnswer] = [:]
            var questions: [Int: QuestionData] = [:]

            for row in rows {
                guard let data = row.answerText.data(using: .utf8),
                      let answer = try? decoder.decode(QuestionAnswer.self, from: data) else {
                    continue
                }
                answers[row.questionNumber] = answer

                if let qd = row.questionJson {
                    questions[row.questionNumber] = qd
                }
            }

            let result = AnswerKeyResult(answers: answers, questions: questions)
            cache[documentId] = result
            return result
        } catch {
            print("[AnswerKeyService] Failed to fetch answer keys: \(error)")
            return AnswerKeyResult(answers: [:], questions: [:])
        }
    }

    func clearCache(documentId: String) {
        cache.removeValue(forKey: documentId)
    }
}
