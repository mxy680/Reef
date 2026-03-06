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
        // Q1 — Titration of para-methoxybenzoic acid
        [
            TutorStep(
                instruction: "Find the Ka using the given pKa of 4.47.",
                hint: "Ka = 10^(-pKa). Plug in 4.47 for pKa.",
                status: .pending,
                progress: 0.6
            ),
            TutorStep(
                instruction: "Determine Kb from the relationship Ka × Kb = Kw.",
                hint: "Kw = 1.0 × 10⁻¹⁴. Divide Kw by the Ka you just found.",
                status: .pending,
                progress: 0.0
            ),
            TutorStep(
                instruction: "Calculate the equivalence point volume and pH at key titration points.",
                hint: "At equivalence, moles of HA = moles of NaOH. Use concentrations to find the volume.",
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
