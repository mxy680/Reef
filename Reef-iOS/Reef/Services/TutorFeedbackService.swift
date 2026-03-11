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
        steps: [AnswerKeyStep],
        strokeCount: Int
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

        // Adaptive exponential debounce: more strokes → shorter delay
        // debounce(n) = 0.5 + 1.5 * e^(-0.15 * n)
        // n=0: 2.0s, n=5: 1.2s, n=10: 0.83s, n=20: 0.57s, n=30+: ~0.5s
        let delay = 0.5 + 1.5 * exp(-0.15 * Double(strokeCount))

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, generation == myGeneration else { return }

            await evaluate(
                subKey: subKey,
                stepIndex: stepIdx,
                progressKey: progressKey,
                latex: latex,
                questionText: questionText,
                steps: steps
            )
        }
    }

    private func evaluate(
        subKey: String,
        stepIndex: Int,
        progressKey: String,
        latex: String,
        questionText: String,
        steps: [AnswerKeyStep]
    ) async {
        // Mark as working while evaluating
        stepProgress[progressKey] = StepProgress(status: .working, progress: stepProgress[progressKey]?.progress ?? 0.0)

        do {
            // Collect completed step indices
            let completedIndices = (0..<stepIndex).filter { i in
                let key = "\(subKey)-\(i)"
                return stepProgress[key]?.status == .completed
            }

            let body = EvaluateStepRequest(
                question_text: questionText,
                student_work: latex,
                steps: steps.map { StepInfo(description: $0.description, work: $0.work) },
                current_step_index: stepIndex,
                completed_step_indices: completedIndices
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

private struct StepInfo: Encodable {
    let description: String
    let work: String
}

private struct EvaluateStepRequest: Encodable {
    let question_text: String
    let student_work: String
    let steps: [StepInfo]
    let current_step_index: Int
    let completed_step_indices: [Int]
}

private struct EvaluateStepResponse: Decodable {
    let progress: Double
    let status: String
}
