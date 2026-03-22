@preconcurrency import Supabase
import Foundation

/// Row shape returned from the `answer_keys` table.
private struct AnswerKeyRow: Codable {
    let documentId: String
    let questionNumber: Int
    let answerText: String

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case questionNumber = "question_number"
        case answerText = "answer_text"
    }
}

struct AnswerKeyResult: Sendable {
    let answers: [Int: QuestionAnswer]
}

struct SupabaseAnswerKeyRepository: Sendable {
    func fetchAnswerKeys(documentId: String) async -> AnswerKeyResult {
        do {
            let rows: [AnswerKeyRow] = try await supabase
                .from("answer_keys")
                .select("document_id, question_number, answer_text")
                .eq("document_id", value: documentId)
                .execute()
                .value

            let decoder = JSONDecoder()
            var answers: [Int: QuestionAnswer] = [:]

            for row in rows {
                guard let data = row.answerText.data(using: .utf8),
                      let answer = try? decoder.decode(QuestionAnswer.self, from: data) else {
                    print("[AnswerKeyRepo] Skipping question \(row.questionNumber): failed to decode")
                    continue
                }
                answers[row.questionNumber] = answer
            }

            return AnswerKeyResult(answers: answers)
        } catch {
            print("[AnswerKeyRepo] Failed to fetch answer keys: \(error)")
            return AnswerKeyResult(answers: [:])
        }
    }
}
