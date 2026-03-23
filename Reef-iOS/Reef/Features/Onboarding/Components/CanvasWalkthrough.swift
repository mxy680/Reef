import SwiftUI

// MARK: - Walkthrough Step

enum WalkthroughStep: Int, CaseIterable {
    // Phase 1: Tool Training
    case drawSomething = 0
    case tryHighlighter
    case eraseHighlight
    case shapeTool
    case lassoTool
    case fingerDraw
    case ruler
    case calculator
    case pageSettings

    // Phase 2: Tutor Training
    case enableTutor
    case readStep
    case tapHint
    case tapAnswer
    case progressBar
    case sidebar
    case ready

    var text: String {
        switch self {
        case .drawSomething: "Grab your Apple Pencil and draw anything. Seriously, anything."
        case .tryHighlighter: "Now tap the highlighter and mark something up."
        case .eraseHighlight: "Now erase what you just highlighted."
        case .shapeTool: "This is for diagrams — draw a shape and Reef cleans it up. Perfect for free-body diagrams, circuits, and graphs."
        case .lassoTool: "Circle any drawing to select it. Move it, resize it, or delete it."
        case .fingerDraw: "Turn this on to draw with your finger instead of just your Pencil."
        case .ruler: "Straight-line ruler. Tap to toggle."
        case .calculator: "Built-in calculator. Because who wants to switch apps."
        case .pageSettings: "Change your page background — grid, dots, lines, or blank."
        case .enableTutor: "Now let's try the AI tutor. It watches your work and helps in real time."
        case .readStep: "Read what the tutor wants you to do for Step 1."
        case .tapHint: "Stuck? Tap this for a hint."
        case .tapAnswer: "Want to see the full answer? Tap here."
        case .progressBar: "This shows how far you are. It fills up as you solve each step."
        case .sidebar: "Your tutor lives here. It shows steps, hints, and chats with you about the problem."
        case .ready: "That's it. Now try solving the problem. Your tutor's watching."
        }
    }

    /// Whether this step requires the user to perform an action (vs just tapping "Got it")
    var requiresAction: Bool {
        switch self {
        case .drawSomething, .tryHighlighter, .eraseHighlight, .enableTutor, .tapHint, .tapAnswer:
            return true
        default:
            return false
        }
    }

    /// Button label for non-action steps
    var buttonLabel: String {
        switch self {
        case .ready: "Let's go"
        case .enableTutor: "Enable tutor mode"
        default: "Got it"
        }
    }

    var position: WalkthroughPopupPosition {
        switch self {
        case .drawSomething: .bottomLeading
        case .tryHighlighter, .eraseHighlight, .shapeTool, .lassoTool, .fingerDraw: .topCenter
        case .ruler, .calculator, .pageSettings: .topTrailing
        case .enableTutor, .ready: .center
        case .readStep, .tapHint, .tapAnswer, .progressBar, .sidebar: .centerTrailing
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
    var isComplete = false

    func advance() {
        guard let current = currentStep else { return }
        let allSteps = WalkthroughStep.allCases
        if let idx = allSteps.firstIndex(of: current), idx + 1 < allSteps.count {
            currentStep = allSteps[idx + 1]
        } else {
            currentStep = nil
            isComplete = true
        }
    }

    func skip() {
        currentStep = nil
        isComplete = true
    }
}
