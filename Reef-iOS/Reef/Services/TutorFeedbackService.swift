//
//  TutorFeedbackService.swift
//  Reef
//
//  Debounces transcription changes and evaluates student progress
//  against the current tutor step via Gemini 3 Flash.
//

import Foundation

@Observable
@MainActor
final class TutorFeedbackService {
    /// Progress per step, keyed by "qi-partLabel-stepIdx"
    var stepProgress: [String: StepProgress] = [:]

    /// Current step index per subquestion, keyed by "qi-partLabel"
    var currentStepIndices: [String: Int] = [:]

    private var debounceTask: Task<Void, Never>?
    private var generation: Int = 0
    private var lastEvaluatedLatex: [String: String] = [:]

    func onTranscriptionChanged(
        questionIndex: Int,
        partLabel: String,
        latex: String,
        questionText: String,
        steps: [AnswerKeyStep]
    ) {
        let subKey = "\(questionIndex)-\(partLabel)"
        let stepIdx = currentStepIndices[subKey] ?? 0
        guard stepIdx < steps.count else { return }

        let progressKey = "\(subKey)-\(stepIdx)"

        // Skip if LaTeX hasn't changed since last evaluation
        if lastEvaluatedLatex[progressKey] == latex { return }

        // Handle empty latex — reset to idle without calling server
        if latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stepProgress[progressKey] = StepProgress(status: .idle, progress: 0.0)
            lastEvaluatedLatex[progressKey] = latex
            debounceTask?.cancel()
            return
        }

        generation += 1
        let myGeneration = generation
        let step = steps[stepIdx]

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled, generation == myGeneration else { return }

            await evaluate(
                subKey: subKey,
                stepIndex: stepIdx,
                progressKey: progressKey,
                latex: latex,
                questionText: questionText,
                step: step
            )
        }
    }

    private func evaluate(
        subKey: String,
        stepIndex: Int,
        progressKey: String,
        latex: String,
        questionText: String,
        step: AnswerKeyStep
    ) async {
        // Mark as working while evaluating
        stepProgress[progressKey] = StepProgress(status: .working, progress: stepProgress[progressKey]?.progress ?? 0.0)

        do {
            let body = EvaluateStepRequest(
                question_text: questionText,
                step_description: step.description,
                step_work: step.work,
                student_work: latex
            )
            let response: EvaluateStepResponse = try await ReefAPI.shared.request(
                "POST",
                path: "/ai/evaluate-step",
                body: body
            )

            // Map string status to StepStatus enum
            let status: StepStatus = switch response.status {
            case "completed": .completed
            case "mistake": .mistake
            case "working": .working
            default: .idle
            }

            stepProgress[progressKey] = StepProgress(status: status, progress: response.progress)
            lastEvaluatedLatex[progressKey] = latex

            print("[TutorFeedback] \(progressKey): \(response.status) (\(Int(response.progress * 100))%)")

            // Auto-advance on completion
            if status == .completed {
                currentStepIndices[subKey] = stepIndex + 1
            }
        } catch {
            print("[TutorFeedback] Error: \(error)")
        }
    }

    /// Manually advance to the next step for the given subquestion.
    func advanceStep(questionIndex: Int, partLabel: String) {
        let subKey = "\(questionIndex)-\(partLabel)"
        let current = currentStepIndices[subKey] ?? 0
        currentStepIndices[subKey] = current + 1
    }

    /// Reset progress when switching questions/parts
    func reset() {
        debounceTask?.cancel()
        // Don't clear stepProgress — keep history for revisited steps
    }
}

// MARK: - API Models

private struct EvaluateStepRequest: Encodable {
    let question_text: String
    let step_description: String
    let step_work: String
    let student_work: String
}

private struct EvaluateStepResponse: Decodable {
    let progress: Double
    let status: String
}
