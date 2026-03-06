//
//  TutorStepData.swift
//  Reef
//
//  Mock tutor step data — hardcoded scaffolding for the step toolbar UI.
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
    let status: StepStatus
    let progress: Double  // 0.0 (cold) to 1.0 (hot)
}

/// Keyed by question index (0-based). Each question has 2–3 steps.
enum MockTutorSteps {
    static let steps: [[TutorStep]] = [
        // Q1
        [
            TutorStep(
                instruction: "Start by identifying what the problem is asking for.",
                hint: "Look for the key variable — what are you solving for?",
                status: .completed,
                progress: 1.0
            ),
            TutorStep(
                instruction: "Write out the known values and assign variables.",
                hint: "List each given quantity with its units before proceeding.",
                status: .pending,
                progress: 0.67
            ),
            TutorStep(
                instruction: "Apply the relevant formula and solve.",
                hint: "Check that your units cancel correctly before computing.",
                status: .pending,
                progress: 0.0
            ),
        ],
        // Q2
        [
            TutorStep(
                instruction: "Read the question carefully and underline the key terms.",
                hint: "Pay attention to qualifiers like 'maximum', 'minimum', or 'all'.",
                status: .mistake,
                progress: 0.7
            ),
            TutorStep(
                instruction: "Set up your equation based on the relationship described.",
                hint: "Think about which law or rule applies to this type of problem.",
                status: .pending,
                progress: 0.1
            ),
        ],
        // Q3
        [
            TutorStep(
                instruction: "Break the problem into smaller sub-problems.",
                hint: "Tackle the simplest part first, then build toward the solution.",
                status: .completed,
                progress: 1.0
            ),
            TutorStep(
                instruction: "Verify your answer makes sense in context.",
                hint: "Does the magnitude and sign of your answer seem reasonable?",
                status: .pending,
                progress: 0.6
            ),
        ],
    ]

    /// Returns the steps for a given question index,
    /// falling back to Q1 steps if index is out of range.
    static func steps(for questionIndex: Int) -> [TutorStep] {
        guard questionIndex < steps.count else { return steps[0] }
        return steps[questionIndex]
    }
}
