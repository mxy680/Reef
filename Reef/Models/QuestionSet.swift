//
//  QuestionSet.swift
//  Reef
//
//  A collection of extracted questions from a document.
//

import Foundation
import SwiftData

/// Status of question extraction process
enum QuestionExtractionStatus: String, Codable {
    case pending
    case extracting
    case completed
    case failed
}

@Model
class QuestionSet {
    var id: UUID = UUID()
    var sourceNoteID: UUID
    var dateExtracted: Date = Date()
    var extractionStatusRaw: String = QuestionExtractionStatus.pending.rawValue
    var errorMessage: String?

    /// Job ID for tracking in-progress extractions (for app restart recovery)
    var extractionJobID: String?

    @Relationship(deleteRule: .cascade, inverse: \Question.questionSet)
    var questions: [Question] = []

    var extractionStatus: QuestionExtractionStatus {
        get { QuestionExtractionStatus(rawValue: extractionStatusRaw) ?? .pending }
        set { extractionStatusRaw = newValue.rawValue }
    }

    /// Number of questions in this set
    var questionCount: Int {
        questions.count
    }

    /// Whether extraction is complete and questions are available
    var isReady: Bool {
        extractionStatus == .completed && !questions.isEmpty
    }

    init(sourceNoteID: UUID) {
        self.sourceNoteID = sourceNoteID
    }
}
