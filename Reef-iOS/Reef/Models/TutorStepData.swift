//
//  TutorStepData.swift
//  Reef
//
//  Tutor step types and conversion from server answer keys.
//

import Foundation

enum StepStatus: String, Codable, Equatable {
    case idle       // Not yet started
    case working    // Actively being worked on
    case mistake    // Error detected
    case completed  // Correct / done
}

struct StepProgress: Codable, Equatable {
    var status: StepStatus
    var progress: Double
    var feedback: String = ""
}

/// Row in the `tutor_progress` Supabase table.
struct TutorProgressRecord: Codable {
    let userId: String
    let documentId: String
    var stepProgress: [String: StepProgress]
    var currentStepIndices: [String: Int]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case documentId = "document_id"
        case stepProgress = "step_progress"
        case currentStepIndices = "current_step_indices"
    }
}

struct TutorStep {
    let instruction: String
    let hint: String
    let work: String
    let status: StepStatus
    let progress: Double  // 0.0 (cold) to 1.0 (hot)
}

/// Convert a `QuestionAnswer` into a flat array of `TutorStep` for the toolbar.
enum TutorStepConverter {
    static func steps(
        from answer: QuestionAnswer,
        progress: [String: StepProgress]? = nil,
        questionIndex: Int = 0
    ) -> [TutorStep] {
        if !answer.parts.isEmpty {
            return answer.parts.flatMap { stepsFromPart($0, progress: progress, questionIndex: questionIndex) }
        }
        return answer.steps.enumerated().map { idx, step in
            let key = "\(questionIndex)-a-\(idx)"
            let sp = progress?[key]
            return TutorStep(
                instruction: step.description,
                hint: step.explanation,
                work: step.work,
                status: sp?.status ?? .idle,
                progress: sp?.progress ?? 0.0
            )
        }
    }

    private static func stepsFromPart(
        _ part: PartAnswer,
        progress: [String: StepProgress]?,
        questionIndex: Int
    ) -> [TutorStep] {
        if !part.parts.isEmpty {
            return part.parts.flatMap { stepsFromPart($0, progress: progress, questionIndex: questionIndex) }
        }

        return part.steps.enumerated().map { idx, step in
            let key = "\(questionIndex)-\(part.label)-\(idx)"
            let sp = progress?[key]
            return TutorStep(
                instruction: step.description,
                hint: step.explanation,
                work: step.work,
                status: sp?.status ?? .idle,
                progress: sp?.progress ?? 0.0
            )
        }
    }
}
