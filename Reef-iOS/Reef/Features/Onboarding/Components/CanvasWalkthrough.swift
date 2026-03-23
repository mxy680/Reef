import SwiftUI

// MARK: - Walkthrough Step

enum WalkthroughStep: Int, CaseIterable {
    // Phase 1: Tool Training
    case drawSomething = 0
    case tryHighlighter
    case eraseHighlight
    case otherTools        // shape, lasso, finger draw combined
    case utilityTools      // ruler, calculator, page settings combined

    // Phase 2: Tutor Training
    case enableTutor
    case tutorFeatures     // read step + hint + answer combined
    case tutorUI           // progress bar + sidebar combined
    case ready

    var text: String {
        switch self {
        case .drawSomething:
            "Grab your Apple Pencil and draw anything. Seriously, anything."
        case .tryHighlighter:
            "Now tap the highlighter and mark something up."
        case .eraseHighlight:
            "Now erase what you just highlighted."
        case .otherTools:
            "A few more tools:\n\n• Shape tool — draw a shape and Reef cleans it up. Great for diagrams.\n• Lasso — circle anything to select, move, or delete it.\n• Finger draw — lets you draw with your finger too."
        case .utilityTools:
            "And some handy extras:\n\n• Ruler — for straight lines.\n• Calculator — built-in, because who wants to switch apps.\n• Page settings — grid, dots, lines, or blank background."
        case .enableTutor:
            "Now let's try the AI tutor. Tap the tutor button to turn it on."
        case .tutorFeatures:
            "Your tutor gives you:\n\n• Step descriptions — what to do next.\n• 💡 Hints — tap the lightbulb when you're stuck.\n• 👁 Answers — tap to reveal the full solution."
        case .tutorUI:
            "A couple more things:\n\n• The progress bar shows how far you've solved.\n• The sidebar is where your tutor lives — steps, hints, and chat."
        case .ready:
            "That's it. Now try solving the problem. Your tutor's watching."
        }
    }

    var requiresAction: Bool {
        switch self {
        case .drawSomething, .tryHighlighter, .eraseHighlight, .enableTutor:
            return true
        default:
            return false
        }
    }

    var buttonLabel: String {
        switch self {
        case .ready: "Let's go"
        default: "Got it"
        }
    }

    var position: WalkthroughPopupPosition {
        switch self {
        case .drawSomething: .bottomLeading
        case .tryHighlighter, .eraseHighlight, .otherTools: .topCenter
        case .utilityTools: .topTrailing
        case .enableTutor, .ready: .center
        case .tutorFeatures, .tutorUI: .centerTrailing
        }
    }
}

enum WalkthroughPopupPosition {
    case bottomLeading
    case topCenter
    case topTrailing
    case center
    case centerTrailing
}

// MARK: - Walkthrough State Machine

@Observable
@MainActor
final class CanvasWalkthroughState {
    var currentStep: WalkthroughStep? = .drawSomething
    var previousStep: WalkthroughStep? = nil
    var isComplete = false

    private var removePreviousTask: Task<Void, Never>?

    func advance() {
        guard let current = currentStep else { return }

        // Previous step becomes the one we're leaving
        removePreviousTask?.cancel()
        previousStep = current

        let allSteps = WalkthroughStep.allCases
        if let idx = allSteps.firstIndex(of: current), idx + 1 < allSteps.count {
            currentStep = allSteps[idx + 1]
        } else {
            currentStep = nil
            isComplete = true
        }

        // Remove previous after a short delay
        removePreviousTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                previousStep = nil
            }
        }
    }

    func skip() {
        removePreviousTask?.cancel()
        currentStep = nil
        previousStep = nil
        isComplete = true
    }
}
