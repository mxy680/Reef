//
//  TutorFeedbackService.swift
//  Reef
//
//  Debounces transcription changes and evaluates student progress
//  against the current tutor step via Gemini 3 Flash.
//  Persists progress to Supabase `tutor_progress` table.
//

import Foundation
@preconcurrency import Supabase

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
    private var isLoaded = false

    init(documentId: String) {
        self.documentId = documentId
    }

    // MARK: - Persistence

    /// Load saved progress from Supabase. Call once from the view's .task block.
    func loadProgress() async {
        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
            let record: TutorProgressRecord = try await supabase
                .from("tutor_progress")
                .select()
                .eq("user_id", value: userId)
                .eq("document_id", value: documentId)
                .single()
                .execute()
                .value
            stepProgress = record.stepProgress
            currentStepIndices = record.currentStepIndices
            print("[TutorFeedback] Loaded progress for \(documentId): \(stepProgress.count) steps, \(currentStepIndices.count) indices")
        } catch {
            // No existing row (PGRST116) or other error — start fresh
            print("[TutorFeedback] No saved progress for \(documentId): \(error)")
        }
        isLoaded = true
    }

    /// Debounced save — call after any state mutation.
    private func scheduleSave() {
        guard isLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            await persistProgress()
        }
    }

    /// Save immediately (e.g. on view disappear). Fire-and-forget.
    func saveImmediately() {
        guard isLoaded else { return }
        saveTask?.cancel()
        Task { await persistProgress() }
    }

    private func persistProgress() async {
        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
            let record = TutorProgressRecord(
                userId: userId,
                documentId: documentId,
                stepProgress: stepProgress,
                currentStepIndices: currentStepIndices
            )
            try await supabase
                .from("tutor_progress")
                .upsert(record)
                .execute()
            print("[TutorFeedback] Saved progress for \(documentId)")
        } catch {
            print("[TutorFeedback] Failed to save progress: \(error)")
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
        guard stepIdx < steps.count else { return }

        let progressKey = "\(subKey)-\(stepIdx)"

        // Skip if LaTeX hasn't changed since last evaluation
        if lastEvaluatedLatex[progressKey] == latex { return }

        // Handle empty latex — reset to idle without calling server
        if latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

            // On mistake, never let progress increase — lock to previous value or lower
            let finalProgress: Double
            if status == .mistake, let existing = stepProgress[progressKey] {
                finalProgress = min(existing.progress, response.progress)
            } else {
                finalProgress = response.progress
            }

            stepProgress[progressKey] = StepProgress(status: status, progress: finalProgress, feedback: response.feedback ?? "")
            lastEvaluatedLatex[progressKey] = latex

            print("[TutorFeedback] \(progressKey): \(response.status) (\(Int(finalProgress * 100))%)")

            // Auto-advance on completion (clamped to last step)
            if status == .completed {
                currentStepIndices[subKey] = min(stepIndex + 1, steps.count - 1)
            }

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
    let feedback: String?
}
