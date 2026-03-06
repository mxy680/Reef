//
//  TutorStepData.swift
//  Reef
//
//  Mock tutor step data — hardcoded scaffolding for the step toolbar UI.
//

import Foundation

struct TutorStep {
    let instruction: String
    let hint: String
}

/// Keyed by question index (0-based). Each question has 2–3 steps.
enum MockTutorSteps {
    static let steps: [[TutorStep]] = [
        // Q1
        [
            TutorStep(
                instruction: "Start by identifying what the problem is asking for.",
                hint: "Look for the key variable — what are you solving for?"
            ),
            TutorStep(
                instruction: "Write out the known values and assign variables.",
                hint: "List each given quantity with its units before proceeding."
            ),
            TutorStep(
                instruction: "Apply the relevant formula and solve.",
                hint: "Check that your units cancel correctly before computing."
            ),
        ],
        // Q2
        [
            TutorStep(
                instruction: "Read the question carefully and underline the key terms.",
                hint: "Pay attention to qualifiers like 'maximum', 'minimum', or 'all'."
            ),
            TutorStep(
                instruction: "Set up your equation based on the relationship described.",
                hint: "Think about which law or rule applies to this type of problem."
            ),
        ],
        // Q3
        [
            TutorStep(
                instruction: "Break the problem into smaller sub-problems.",
                hint: "Tackle the simplest part first, then build toward the solution."
            ),
            TutorStep(
                instruction: "Verify your answer makes sense in context.",
                hint: "Does the magnitude and sign of your answer seem reasonable?"
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
