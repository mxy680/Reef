//
//  TutorStepData.swift
//  Reef
//
//  Tutor step types and conversion from server answer keys.
//

import Foundation

enum StepStatus {
    case idle       // Not yet started
    case working    // Actively being worked on
    case mistake    // Error detected
    case completed  // Correct / done
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
    static func steps(from answer: QuestionAnswer) -> [TutorStep] {
        if !answer.parts.isEmpty {
            return answer.parts.flatMap { stepsFromPart($0) }
        }
        return answer.steps.map { step in
            TutorStep(
                instruction: step.description,
                hint: step.explanation,
                work: step.work,
                status: .idle,
                progress: 0.0
            )
        }
    }

    private static func stepsFromPart(_ part: PartAnswer) -> [TutorStep] {
        if !part.parts.isEmpty {
            return part.parts.flatMap { stepsFromPart($0) }
        }

        return part.steps.map { step in
            TutorStep(
                instruction: step.description,
                hint: step.explanation,
                work: step.work,
                status: .idle,
                progress: 0.0
            )
        }
    }
}
