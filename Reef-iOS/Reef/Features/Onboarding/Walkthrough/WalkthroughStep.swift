import SwiftUI

// MARK: - Walkthrough Phase

enum WalkthroughPhase: Int, CaseIterable {
    case toolTraining   // drawSomething...pageSettings
    case tutorTraining  // enableTutor...tutorReveal
    case solveIt        // solveIt
    case postSolve      // voiceCommand...ready
}

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
    case tutorHint
    case tutorReveal

    // Phase 3: Solve the problem (user works freely)
    case solveIt

    // Phase 4: After solving — remaining features
    case voiceCommand
    case sidebarToggle
    case bugReport
    case exportFeature
    case ready

    // MARK: - Phase

    var phase: WalkthroughPhase {
        switch self {
        case .drawSomething, .tryHighlighter, .eraseHighlight,
             .shapeTool, .lassoTool, .fingerDraw,
             .ruler, .calculator, .pageSettings:
            return .toolTraining
        case .enableTutor, .tutorHint, .tutorReveal:
            return .tutorTraining
        case .solveIt:
            return .solveIt
        case .voiceCommand, .sidebarToggle, .bugReport, .exportFeature, .ready:
            return .postSolve
        }
    }

    // MARK: - Display Text

    /// What's displayed in the walkthrough popup card.
    var text: String {
        switch self {
        // Phase 1: Tool Training
        case .drawSomething:
            "Don't worry about the question on your screen yet — we'll get to that. First, grab your Apple Pencil and draw something fun. Literally anything — a cat, a stick figure, whatever comes to mind."
        case .tryHighlighter:
            "Tap the highlighter tool up top. It's transparent, so it layers over your ink — great for annotating."
        case .eraseHighlight:
            "Made a mess? Good. Tap the eraser and clean it up — it removes anything you draw over."
        case .shapeTool:
            "The shape tool turns your rough sketches into clean geometry — draw it ugly, Reef makes it pretty. Always use this for diagrams though. Your tutor needs to know what's math and what's art, and honestly? It can't always tell."
        case .lassoTool:
            "Try the lasso. Draw a loop around something — now you can drag it, scale it, or send it to the abyss."
        case .fingerDraw:
            "Don't have your Pencil handy? Tap finger draw and sketch with your finger instead — same canvas, just your fingertip."
        case .ruler:
            "Tap the ruler tool. A straight edge appears on the canvas — rotate it, position it, draw along it. No more diagrams that look like they survived a tsunami."
        case .calculator:
            "Need to check your math? Tap the calculator — it floats right on your canvas so you never lose your place."
        case .pageSettings:
            "Tap page settings to change your canvas background. Graph paper for plotting, dot grid for diagrams, lined for notes — pick whatever helps you think."
        // Phase 2: Tutor Training
        case .enableTutor:
            "Here's what makes Reef different. Tap the tutor toggle — your AI reads your handwriting live, knows the answer key, and coaches you without giving it away."
        case .tutorHint:
            "See the Hint section in the sidebar? Tap it to expand — your tutor gives you a nudge without spoiling the answer. Training wheels, not a cheat code."
        case .tutorReveal:
            "Now tap Full Solution in the sidebar. It shows you the complete work for this step — sometimes you just need to see how it's done. No judgment."
        // Phase 3: Solve It
        case .solveIt:
            "OK dive in. Work through the problem step by step — your tutor reads your handwriting in real time and jumps in when you need a hand."
        // Phase 4: Post-Solve
        case .voiceCommand:
            "Tap the mic to talk to your tutor. Ask a question about the problem, or just chat — it's like office hours but you don't have to leave your desk."
        case .sidebarToggle:
            "Need more canvas space? Tap the sidebar icon to hide the tutor panel. Tap it again to bring it back when you want help."
        case .bugReport:
            "See the bug icon? That's your direct line to us. If something's off, let us know — we read every single report. Seriously."
        case .exportFeature:
            "Tap export to save your canvas as a PDF — drawings, annotations, everything. Perfect for submitting homework or saving your notes."
        case .ready:
            "That's everything. You know the tools, you've met your tutor, and you crushed a problem. Now go dive in for real."
        }
    }

    // MARK: - Speech Text

    /// TTS-optimized version with full sentences, emphasis, and precise punctuation for Orpheus voice model.
    var speech: String {
        switch self {
        // Phase 1: Tool Training
        case .drawSomething:
            "Don't worry about the question on your screen yet. We'll get to that. First, grab your Apple Pencil, and draw something fun. LITERALLY anything. A cat, a stick figure, whatever comes to mind."
        case .tryHighlighter:
            "Now tap the highlighter tool, up at the top. It's transparent, so it layers RIGHT over your ink. It's great for annotating your work."
        case .eraseHighlight:
            "Made a mess? GOOD. Now tap the eraser, and clean it up. It removes ANYTHING you draw over."
        case .shapeTool:
            "The shape tool turns your rough sketches into clean geometry. Draw it ugly, Reef makes it pretty. ALWAYS use this for diagrams though. Your tutor needs to know what's math, and what's art. And honestly? It can't always tell."
        case .lassoTool:
            "Now try the lasso tool. Draw a loop around something you drew. Now you can DRAG it, SCALE it, or send it straight to the abyss."
        case .fingerDraw:
            "Don't have your Pencil handy? Tap the finger draw tool, and sketch with your finger instead. Same canvas, just your fingertip."
        case .ruler:
            "Tap the ruler tool. A straight edge will appear on the canvas. You can rotate it, position it, and draw along it. No more diagrams that look like they survived a TSUNAMI."
        case .calculator:
            "Need to check your math? Tap the calculator. It floats RIGHT on your canvas, so you NEVER lose your place."
        case .pageSettings:
            "Tap page settings to change your canvas background. Graph paper for plotting. Dot grid for diagrams. Lined for notes. Pick whatever helps you think."
        // Phase 2: Tutor Training
        case .enableTutor:
            "HERE is what makes Reef different. Tap the tutor toggle. Your A.I. reads your handwriting LIVE, knows the answer key, and coaches you, without giving it away."
        case .tutorHint:
            "See the Hint section in the sidebar? Tap it to expand. Your tutor gives you a nudge, WITHOUT spoiling the answer. Training wheels. NOT a cheat code."
        case .tutorReveal:
            "Now tap Full Solution in the sidebar. It shows you the COMPLETE work for this step. Sometimes, you just need to see how it's done. No judgment."
        // Phase 3: Solve It
        case .solveIt:
            "OK, DIVE IN. Work through the problem, step by step. Your tutor reads your handwriting in REAL time, and will jump in when you need a hand."
        // Phase 4: Post-Solve
        case .voiceCommand:
            "Tap the mic, to talk to your tutor. Ask a question about the problem, or just CHAT. It's like office hours, but you don't have to leave your desk."
        case .sidebarToggle:
            "Need more canvas space? Tap the sidebar icon, to HIDE the tutor panel. Tap it again, to bring it back when you want help."
        case .bugReport:
            "See the bug icon? That is your DIRECT line to us. If something's off, let us know. We read EVERY single report. Seriously."
        case .exportFeature:
            "Tap export, to save your canvas as a P.D.F. Drawings, annotations, EVERYTHING. Perfect for submitting homework, or saving your notes."
        case .ready:
            "That's EVERYTHING. You know the tools, you've met your tutor, and you CRUSHED a problem. Now, go dive in for real."
        }
    }

    // MARK: - Action Properties

    var requiresAction: Bool {
        true
    }

    var buttonLabel: String {
        ""
    }

    // MARK: - Target Highlights

    /// Which drawing tool this step targets (for glow highlight).
    var targetDrawingTool: CanvasToolType? {
        switch self {
        case .tryHighlighter: .highlighter
        case .eraseHighlight: .eraser
        case .shapeTool: .shapes
        case .lassoTool: .lasso
        case .fingerDraw: .handDraw
        default: nil
        }
    }

    /// Which utility/right-side button this step targets (for glow highlight).
    enum TargetButton: String {
        case ruler, calculator, pageSettings
        case mic, sidebar, bugReport, export
        case tutorToggle, hint, reveal
    }

    var targetButton: TargetButton? {
        switch self {
        case .ruler: .ruler
        case .calculator: .calculator
        case .pageSettings: .pageSettings
        case .enableTutor: .tutorToggle
        case .tutorHint: .hint
        case .tutorReveal: .reveal
        case .voiceCommand: .mic
        case .sidebarToggle: .sidebar
        case .bugReport: .bugReport
        case .exportFeature: .export
        default: nil
        }
    }
}
