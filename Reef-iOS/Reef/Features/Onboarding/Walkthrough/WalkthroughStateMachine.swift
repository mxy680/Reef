import SwiftUI

// MARK: - Walkthrough State Machine

@Observable
@MainActor
final class WalkthroughStateMachine {
    var currentStep: WalkthroughStep? = .drawSomething
    var isComplete = false
    var drawingReaction: String?

    var currentPhase: WalkthroughPhase? { currentStep?.phase }

    private var unlockedPhases: Set<WalkthroughPhase> = [.toolTraining]

    // MARK: - Navigation

    func advance() {
        guard let current = currentStep else { return }
        let all = WalkthroughStep.allCases
        guard let idx = all.firstIndex(of: current) else { return }
        let nextIdx = all.index(after: idx)
        guard nextIdx < all.endIndex else {
            currentStep = nil
            isComplete = true
            return
        }
        let next = all[nextIdx]
        // Phase gate: only cross phase boundary if next phase is unlocked
        if next.phase != current.phase && !unlockedPhases.contains(next.phase) {
            return
        }
        currentStep = next
    }

    func unlockNextPhase() {
        guard let current = currentStep else { return }
        let allPhases = WalkthroughPhase.allCases
        guard let idx = allPhases.firstIndex(of: current.phase),
              idx + 1 < allPhases.count else { return }
        unlockedPhases.insert(allPhases[idx + 1])
    }

    func jumpToPhase(_ phase: WalkthroughPhase) {
        // Unlock all phases up to and including the target
        for p in WalkthroughPhase.allCases where p.rawValue <= phase.rawValue {
            unlockedPhases.insert(p)
        }
        currentStep = WalkthroughStep.allCases.first { $0.phase == phase }
    }

    func skipTutorial() {
        currentStep = nil
        isComplete = true
    }

    // MARK: - Skip-ahead helper (mirrors old skipToAndAdvance)

    /// Skip ahead to a step (or advance if already on it), then advance past it after a delay.
    /// Only works after the user has started (past drawSomething).
    func skipToAndAdvance(_ target: WalkthroughStep, delayMs: Int = 1000) {
        guard let current = currentStep,
              current != .drawSomething
        else { return }

        if target.rawValue == current.rawValue {
            scheduleAdvance(ms: delayMs)
        } else if target.rawValue > current.rawValue {
            currentStep = target
            scheduleAdvance(ms: delayMs)
        }
    }

    // MARK: - Delayed Advance

    private var pendingAdvanceTask: Task<Void, Never>?

    func scheduleAdvance(ms: Int) {
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(ms))
            guard !Task.isCancelled, let self else { return }
            self.advance()
        }
    }

    func cancelPendingAdvance() {
        pendingAdvanceTask?.cancel()
    }
}
