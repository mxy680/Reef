//
//  TutorFeedbackService.swift
//  Reef
//
//  Debounces transcription changes and evaluates student progress
//  against the current tutor step via Gemini 3 Flash.
//  Persists progress locally via TutorProgressStorageService.
//

import Foundation

@Observable
@MainActor
final class TutorFeedbackService {
    /// Progress per step, keyed by "qi-partLabel-stepIdx"
    var stepProgress: [String: StepProgress] = [:]

    /// Current step index per subquestion, keyed by "qi-partLabel"
    var currentStepIndices: [String: Int] = [:]

    let documentId: String

    private var debounceTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var generation: Int = 0
    private var lastEvaluatedLatex: [String: String] = [:]

    init(documentId: String) {
        self.documentId = documentId
    }

    // MARK: - Persistence

    /// Debounced save — call after any state mutation.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            saveProgress(for: documentId)
        }
    }

    // MARK: - Evaluation

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

        print("[TutorFeedback] onTranscriptionChanged: subKey=\(subKey) stepIdx=\(stepIdx) steps.count=\(steps.count) latex=\(latex.prefix(60))")

        guard stepIdx < steps.count else {
            print("[TutorFeedback] SKIPPED: stepIdx(\(stepIdx)) >= steps.count(\(steps.count))")
            return
        }

        let progressKey = "\(subKey)-\(stepIdx)"

        // Skip if LaTeX hasn't changed since last evaluation
        if lastEvaluatedLatex[progressKey] == latex {
            print("[TutorFeedback] SKIPPED: latex unchanged for \(progressKey)")
            return
        }

        // Handle empty latex — reset to idle without calling server
        if latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[TutorFeedback] Empty latex → idle for \(progressKey)")
            stepProgress[progressKey] = StepProgress(status: .idle, progress: 0.0)
            lastEvaluatedLatex[progressKey] = latex
            debounceTask?.cancel()
            scheduleSave()
            return
        }

        generation += 1
        let myGeneration = generation

        // Adaptive exponential debounce: more strokes → shorter delay
        // debounce(n) = 0.5 + 1.5 * e^(-0.15 * n)
        // n=0: 2.0s, n=5: 1.2s, n=10: 0.83s, n=20: 0.57s, n=30+: ~0.5s
        let delay = 0.5 + 1.5 * exp(-0.15 * Double(strokeCount))

        print("[TutorFeedback] Scheduling eval gen=\(myGeneration) delay=\(String(format: "%.2f", delay))s for \(progressKey)")

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, generation == myGeneration else {
                print("[TutorFeedback] Debounce cancelled/stale gen=\(myGeneration) current=\(generation)")
                return
            }

            print("[TutorFeedback] Calling evaluate for \(progressKey)")
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
        print("[TutorFeedback] evaluate() START for \(progressKey), questionText=\(questionText.prefix(40)), steps=\(steps.count)")
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
            print("[TutorFeedback] Sending POST /ai/evaluate-step body: step_index=\(stepIndex) student_work=\(latex.prefix(60))")
            let response: EvaluateStepResponse = try await ReefAPI.shared.request(
                "POST",
                path: "/ai/evaluate-step",
                body: body
            )
            print("[TutorFeedback] Server responded: status=\(response.status) progress=\(response.progress)")

            // Map string status to StepStatus enum
            let status: StepStatus = switch response.status {
            case "completed": .completed
            case "mistake": .mistake
            case "working": .working
            default: .idle
            }

            stepProgress[progressKey] = StepProgress(status: status, progress: response.progress, mistakeExplanation: response.mistake_explanation)
            lastEvaluatedLatex[progressKey] = latex

            print("[TutorFeedback] \(progressKey): \(response.status) (\(Int(response.progress * 100))%)")

            scheduleSave()
        } catch {
            print("[TutorFeedback] Error: \(error)")
        }
    }

    /// Manually advance to the next step for the given subquestion.
    func advanceStep(questionIndex: Int, partLabel: String, totalSteps: Int) {
        let subKey = "\(questionIndex)-\(partLabel)"
        let current = currentStepIndices[subKey] ?? 0
        currentStepIndices[subKey] = min(current + 1, totalSteps - 1)
        scheduleSave()
    }

    /// Reset a specific subquestion back to step 0, clearing all step progress.
    func resetProblem(questionIndex: Int, partLabel: String) {
        let subKey = "\(questionIndex)-\(partLabel)"
        currentStepIndices[subKey] = 0
        // Clear all step progress for this subquestion
        let keysToRemove = stepProgress.keys.filter { $0.hasPrefix("\(subKey)-") }
        for key in keysToRemove {
            stepProgress.removeValue(forKey: key)
        }
        lastEvaluatedLatex = lastEvaluatedLatex.filter { !$0.key.hasPrefix("\(subKey)-") }
        scheduleSave()
    }

    /// Reset progress when switching questions/parts
    func reset() {
        debounceTask?.cancel()
        // Don't clear stepProgress — keep history for revisited steps
    }

    /// Save progress to disk for the given document.
    func saveProgress(for documentId: String) {
        guard !stepProgress.isEmpty else { return }
        TutorProgressStorageService.save(
            stepProgress: stepProgress,
            currentStepIndices: currentStepIndices,
            for: documentId
        )
    }

    /// Load saved progress from disk.
    func loadProgress(for documentId: String) {
        guard let stored = TutorProgressStorageService.load(for: documentId) else { return }
        stepProgress = stored.stepProgress
        currentStepIndices = stored.currentStepIndices
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
    let mistake_explanation: String?
}
