import Foundation
@preconcurrency import Supabase

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

actor AnswerKeyService {
    static let shared = AnswerKeyService()

    /// In-memory cache keyed by document ID.
    private var cache: [String: [Int: QuestionAnswer]] = [:]

    /// Fetch answer keys for a document, returning a dictionary keyed by question number (1-based).
    func fetchAnswerKeys(documentId: String) async -> [Int: QuestionAnswer] {
        if let cached = cache[documentId] { return cached }

        do {
            let rows: [AnswerKeyRow] = try await supabase
                .from("answer_keys")
                .select("document_id, question_number, answer_text")
                .eq("document_id", value: documentId)
                .execute()
                .value

            let decoder = JSONDecoder()
            var result: [Int: QuestionAnswer] = [:]
            for row in rows {
                guard let data = row.answerText.data(using: .utf8),
                      let answer = try? decoder.decode(QuestionAnswer.self, from: data) else {
                    continue
                }
                result[row.questionNumber] = answer
            }
            cache[documentId] = result
            return result
        } catch {
            print("[AnswerKeyService] Failed to fetch answer keys: \(error)")
            return [:]
        }
    }

    func clearCache(documentId: String) {
        cache.removeValue(forKey: documentId)
    }
}
