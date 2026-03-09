//
//  TutorStepData.swift
//  Reef
//
//  Tutor step types and conversion from server answer keys.
//

import Foundation

enum StepStatus {
    case pending
    case mistake
    case completed
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
                status: .pending,
                progress: 0.0
            )
        }
    }

    private static func stepsFromPart(_ part: PartAnswer, prefix: String? = nil) -> [TutorStep] {
        let label = prefix.map { "\($0)(\(part.label))" } ?? "(\(part.label))"

        // Recurse into nested sub-parts
        if !part.parts.isEmpty {
            return part.parts.flatMap { stepsFromPart($0, prefix: label) }
        }

        return part.steps.map { step in
            TutorStep(
                instruction: "\(label) \(step.description)",
                hint: step.explanation,
                work: step.work,
                status: .pending,
                progress: 0.0
            )
        }
    }
}
