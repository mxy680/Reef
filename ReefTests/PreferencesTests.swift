//
//  PreferencesTests.swift
//  ReefTests
//
//  Local integration tests for PreferencesManager — no server required.
//  PreferencesManager uses @AppStorage which writes to UserDefaults.standard.
//

import Testing
import Foundation
@testable import Reef

@Suite("Preferences")
@MainActor
struct PreferencesTests {

    @Test("reasoning model default is Gemini Pro")
    func reasoningModelDefaultIsGeminiPro() {
        #expect(PreferencesManager.shared.selectedReasoningModel == .geminiPro)
    }

    @Test("set and get feedback detail level")
    func setAndGetFeedbackDetailLevel() {
        let original = PreferencesManager.shared.feedbackDetailLevel
        PreferencesManager.shared.feedbackDetailLevel = FeedbackDetailLevel.detailed.rawValue
        #expect(PreferencesManager.shared.selectedFeedbackDetailLevel == .detailed)
        PreferencesManager.shared.feedbackDetailLevel = original
    }

    @Test("quiz default question count")
    func quizDefaultQuestionCount() {
        #expect(PreferencesManager.shared.quizDefaultQuestionCount == 10)
    }

    @Test("question type toggle")
    func questionTypeToggle() {
        // Ensure .fillInBlank is not selected before starting
        let originalData = PreferencesManager.shared.quizPreferredQuestionTypesData

        // Add .fillInBlank if not already present
        var types = PreferencesManager.shared.quizPreferredQuestionTypes
        types.insert(QuestionType.fillInBlank.rawValue)
        PreferencesManager.shared.quizPreferredQuestionTypes = types
        #expect(PreferencesManager.shared.isQuestionTypeSelected(.fillInBlank) == true)

        // Remove .fillInBlank — only allowed if there are other types
        PreferencesManager.shared.quizPreferredQuestionTypes = [QuestionType.multipleChoice.rawValue]
        #expect(PreferencesManager.shared.isQuestionTypeSelected(.fillInBlank) == false)

        // Restore original state
        PreferencesManager.shared.quizPreferredQuestionTypesData = originalData
    }

    @Test("selected time limit convenience getter")
    func selectedTimeLimitConvenienceGetter() {
        let original = PreferencesManager.shared.quizDefaultTimeLimit
        PreferencesManager.shared.quizDefaultTimeLimit = TimeLimitOption.minutes45.rawValue
        #expect(PreferencesManager.shared.selectedQuizTimeLimit == .minutes45)
        #expect(PreferencesManager.shared.selectedQuizTimeLimit.minutes == 45)
        PreferencesManager.shared.quizDefaultTimeLimit = original
    }
}
