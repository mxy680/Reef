//
//  Question.swift
//  Reef
//
//  A single extracted question from a document.
//

import Foundation
import SwiftData

@Model
class Question {
    var id: UUID = UUID()
    var questionSet: QuestionSet?
    var orderIndex: Int
    var fileName: String
    var questionNumber: String?
    var hasImages: Bool = false
    var hasTables: Bool = false

    /// File URL for the question PDF
    var fileURL: URL {
        FileStorageService.shared.getQuestionFileURL(
            questionSetID: questionSet?.id ?? UUID(),
            fileName: fileName
        )
    }

    init(
        questionSet: QuestionSet? = nil,
        orderIndex: Int,
        fileName: String,
        questionNumber: String? = nil,
        hasImages: Bool = false,
        hasTables: Bool = false
    ) {
        self.questionSet = questionSet
        self.orderIndex = orderIndex
        self.fileName = fileName
        self.questionNumber = questionNumber
        self.hasImages = hasImages
        self.hasTables = hasTables
    }
}
