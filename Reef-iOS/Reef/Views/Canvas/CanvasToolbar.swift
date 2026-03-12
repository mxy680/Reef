//
//  CanvasToolbar.swift
//  Reef
//
//  Two-row toolbar: tutor info strip (Row 1) + drawing tools (Row 2).
//  All questions are shown in a single scrollable canvas — no tabs.
//

import SwiftUI

enum PageAction {
    case addBlankAtEnd
    case addBlankAfterCurrent
    case deleteCurrentPage
    case deleteAllPages
    case undo
}

struct CanvasToolbar: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var selectedTool: CanvasTool
    var visibleQuestionIndex: Int = 0
    let onClose: () -> Void
    @Binding var tutorModeOn: Bool
    let isReconstructed: Bool
    var documentName: String = ""
    var answerKey: QuestionAnswer? = nil
    var questionCount: Int = 1
    var onPageAction: ((PageAction) -> Void)?
    @Binding var showPageMenu: Bool
    @Binding var showRuler: Bool
    var onUndo: () -> Void = {}
    var onRedo: () -> Void = {}
    var onToolRetapped: (CanvasTool) -> Void = { _ in }
    @Binding var selectedToolMidX: CGFloat
    @Binding var showPageSettings: Bool
    @Binding var pageSettingsMidX: CGFloat
    @Binding var pageMenuMidX: CGFloat
    var activePartLabel: String? = nil
    var hasActiveOverlay: Bool = false
    @Binding var pageOverlaySettings: PageOverlaySettings
    @Binding var showTutorPopover: Bool
    var stepProgressData: [String: StepProgress]? = nil
    var currentStepIndex: Int = 0
    var totalStepCount: Int = 0
    var onAdvanceStep: () -> Void = {}
    var onResetProblem: () -> Void = {}

    // Tutor popover state (owned here so overlay covers Row 2)
    @State private var showHint = false
    @State private var showReveal = false
    @State private var hintMidX: CGFloat = 0
    @State private var revealMidX: CGFloat = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var toolbarRowMinX: CGFloat = 0
    @State private var toolbarRowWidth: CGFloat = 0

    static let tutorPopoverWidth: CGFloat = 320

    /// Current tutor step (computed from answerKey)
    private var tutorSteps: [TutorStep] {
        guard let answerKey else { return [] }
        return TutorStepConverter.steps(from: answerKey, progress: stepProgressData, questionIndex: visibleQuestionIndex)
    }

    private var currentTutorStep: TutorStep? {
        tutorSteps.first(where: { $0.status != .completed }) ?? tutorSteps.last
    }

    /// Progress for the current step (0.0–1.0).
    private var stepProgress: Double {
        currentTutorStep?.progress ?? 0
    }

    /// Whether the step at currentStepIndex is completed.
    private var isCurrentStepCompleted: Bool {
        guard currentStepIndex < tutorSteps.count else { return false }
        return tutorSteps[currentStepIndex].status == .completed
    }

    /// Whether the step at currentStepIndex has a mistake.
    private var isCurrentStepMistake: Bool {
        guard currentStepIndex < tutorSteps.count else { return false }
        return tutorSteps[currentStepIndex].status == .mistake
    }

    /// Formatted question label, e.g. "Q1" or "Q1 (a)"
    private var questionLabel: String {
        let base = "Q\(visibleQuestionIndex + 1)"
        if let label = activePartLabel {
            return "\(base) (\(label))"
        }
        return base
    }

    /// The single toolbar teal — everything derives from this via white/black opacity.
    static let barColor = Color(hex: 0x4E8A97)
    private static let darkBarColor = ReefColors.CanvasDark.toolbar

    private var activeBarColor: Color {
        theme.isDarkMode ? Self.darkBarColor : Self.barColor
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Info strip (home + tutor step or doc name + tutor toggle)
            infoStrip

            // Row 2: Tool bar
            HStack(spacing: 0) {
                leftSection

                Spacer(minLength: 0)
                centerSection
                makeDivider()
                canvasUtilitiesSection
                makeDivider()
                aiSection
                Spacer(minLength: 0)

                rightSection
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(activeBarColor)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        toolbarRowMinX = geo.frame(in: .global).minX
                        toolbarRowWidth = geo.size.width
                    }
                    .onChange(of: geo.size) { _, _ in
                        toolbarRowMinX = geo.frame(in: .global).minX
                        toolbarRowWidth = geo.size.width
                    }
                }
            )
            // Tutor hint/reveal popovers — hang below Row 2, arrow points up.
            // Zero-height anchor at .bottomLeading so the scale transition
            // originates from Row 2's bottom edge (the arrow tip), matching
            // the drawing-tool popover animation exactly.
            .overlay(alignment: .bottomLeading) {
                if let step = currentTutorStep, showHint {
                    Color.clear.frame(height: 0)
                        .overlay(alignment: .topLeading) {
                            tutorPopoverCard(triggerMidX: hintMidX, title: "Hint", text: step.hint)
                        }
                }
            }
            .animation(.easeOut(duration: 0.2), value: showHint)
            .overlay(alignment: .bottomLeading) {
                if let step = currentTutorStep, showReveal {
                    Color.clear.frame(height: 0)
                        .overlay(alignment: .topLeading) {
                            tutorPopoverCard(triggerMidX: revealMidX, title: "Answer", text: step.work)
                        }
                }
            }
            .animation(.easeOut(duration: 0.2), value: showReveal)
            .zIndex(1)

            // Bottom separator
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .padding(.top, safeAreaTop)
        .background(
            // Strip bg extends into safe area
            ZStack {
                activeBarColor
                Color.black.opacity(theme.isDarkMode ? 0.3 : 0.18)
            }
            .ignoresSafeArea(edges: .top)
        )
        .onChange(of: showHint) { _, _ in
            showTutorPopover = showHint || showReveal
        }
        .onChange(of: showReveal) { _, _ in
            showTutorPopover = showHint || showReveal
        }
        .onChange(of: showTutorPopover) { _, newValue in
            if !newValue { showHint = false; showReveal = false }
        }
        .onChange(of: visibleQuestionIndex) { _, _ in
            showHint = false; showReveal = false
        }
    }

    // MARK: - Tutor Popover

    /// Max popover body height = 40% of screen height.
    private var popoverMaxHeight: CGFloat {
        UIScreen.main.bounds.height * 0.4
    }

    private func tutorPopoverCard(triggerMidX: CGFloat, title: String, text: String) -> some View {
        let idealX = triggerMidX - toolbarRowMinX - Self.tutorPopoverWidth / 2
        let clampedX = max(12, min(idealX, toolbarRowWidth - Self.tutorPopoverWidth - 12))
        let arrowOffset = (triggerMidX - toolbarRowMinX) - (clampedX + Self.tutorPopoverWidth / 2)

        return PopoverCard(arrowOffset: arrowOffset, maxWidth: Self.tutorPopoverWidth) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ReefColors.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                RenderedLatexImage(
                    text: text,
                    maxWidth: Int(Self.tutorPopoverWidth - 24),
                    maxHeight: popoverMaxHeight - 50
                )
            }
            .padding(12)
            .frame(width: Self.tutorPopoverWidth, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
        .offset(x: clampedX)
    }

    // MARK: - Info Strip (Row 1)

    /// Strip background: barColor darkened by overlaying black.
    private var stripBg: some View {
        ZStack {
            activeBarColor
            Color.black.opacity(theme.isDarkMode ? 0.3 : 0.18)
        }
    }

    private var infoStrip: some View {
        HStack(spacing: 0) {
            // Home button
            HStack(spacing: 0) {
                Button {
                    onClose()
                } label: {
                    Image("canvas.home")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }

            // Center content
            if tutorModeOn && isReconstructed {
                TutorStepRow(
                    questionIndex: visibleQuestionIndex,
                    activePartLabel: activePartLabel,
                    answerKey: answerKey,
                    stepProgressData: stepProgressData,
                    currentStepIndex: currentStepIndex,
                    totalStepCount: totalStepCount,
                    onMistakeTapped: {
                        showReveal = false
                        showHint = true
                    }
                )
            } else {
                // Document name / question label
                Spacer()
                if isReconstructed && questionCount > 1 {
                    Text(questionLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(documentName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
            }

            // Progress bar + tutor toggle (right)
            if isReconstructed {
                HStack(spacing: 0) {
                    if tutorModeOn && currentTutorStep != nil {
                        HStack(spacing: 6) {
                            progressBar(progress: stepProgress)

                            HStack(spacing: 0) {
                                Text("\(Int(stepProgress * 100))")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                Text("%")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .baselineOffset(1.5)
                            }

                            // Reset problem button
                            if currentStepIndex > 0 || isCurrentStepCompleted {
                                Button(action: onResetProblem) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.white.opacity(0.25))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }

                            if isCurrentStepCompleted {
                                if currentStepIndex < totalStepCount - 1 {
                                    // Next step chevron
                                    Button(action: onAdvanceStep) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Color.white.opacity(0.25))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.scale.combined(with: .opacity))
                                } else {
                                    // All steps done — show continue / done
                                    Button(action: onAdvanceStep) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .black))
                                            Text("Done")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(Color(hex: 0x81C784))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isCurrentStepCompleted)

                        // Divider between progress and tutor toggle
                        Text("|")
                            .font(.system(size: 20, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 16)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Toggle("", isOn: $tutorModeOn)
                            .toggleStyle(TutorToggleStyle())
                            .labelsHidden()
                    }
                }
                .padding(.trailing, 10)
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(stripBg)
    }

    // MARK: - Left Section (Undo / Redo)

    private var leftSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "arrow.uturn.backward", isSelected: false, action: onUndo)
            ToolbarButton(icon: "arrow.uturn.forward", isSelected: false, action: onRedo)
        }
    }

    // MARK: - Center Section (Drawing Tools)

    private var centerSection: some View {
        HStack(spacing: 0) {
            ForEach(CanvasTool.allCases, id: \.self) { tool in
                ToolbarButton(
                    icon: tool.icon,
                    isSelected: selectedTool == tool,
                    isCustomIcon: tool.isCustomIcon,
                    action: {
                        if selectedTool != tool {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTool = tool
                            }
                        }
                        if tool.hasSettings {
                            onToolRetapped(tool)
                        }
                    }
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: selectedTool) { _, newTool in
                                if newTool == tool {
                                    selectedToolMidX = geo.frame(in: .global).midX
                                }
                            }
                            .onAppear {
                                if selectedTool == tool {
                                    selectedToolMidX = geo.frame(in: .global).midX
                                }
                            }
                    }
                )
            }
        }
    }

    // MARK: - Canvas Utilities (Ruler, Background, Pages)

    private var canvasUtilitiesSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(
                icon: "pencil.and.ruler.fill",
                isSelected: showRuler,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRuler.toggle()
                    }
                }
            )
            ToolbarButton(icon: "canvas.page_settings", isSelected: hasActiveOverlay, isCustomIcon: true, action: {
                showPageSettings = true
            })
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            pageSettingsMidX = geo.frame(in: .global).midX
                        }
                        .onChange(of: showPageSettings) { _, _ in
                            pageSettingsMidX = geo.frame(in: .global).midX
                        }
                }
            )

            // Page menu button
            ToolbarButton(
                icon: "canvas.add_page",
                isSelected: showPageMenu,
                isCustomIcon: true,
                action: { showPageMenu = true }
            )
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            pageMenuMidX = geo.frame(in: .global).midX
                        }
                        .onChange(of: showPageMenu) { _, _ in
                            pageMenuMidX = geo.frame(in: .global).midX
                        }
                }
            )
        }
    }

    // MARK: - AI Section (Mic + More)

    private var aiSection: some View {
        HStack(spacing: 0) {
            // Hint + Reveal buttons (tutor mode only)
            if tutorModeOn && isReconstructed && currentTutorStep != nil {
                stepButton(icon: "lightbulb.fill", isActive: showHint) {
                    showHint.toggle()
                    if showHint { showReveal = false }
                }
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { hintMidX = geo.frame(in: .global).midX }
                        .onChange(of: geo.frame(in: .global).midX) { _, v in hintMidX = v }
                })

                stepButton(icon: "eye.fill", isActive: showReveal) {
                    showReveal.toggle()
                    if showReveal { showHint = false }
                }
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { revealMidX = geo.frame(in: .global).midX }
                        .onChange(of: geo.frame(in: .global).midX) { _, v in revealMidX = v }
                })

                makeDivider()
            }

            // Mic (push to talk)
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 36, height: 36)
        }
    }

    // MARK: - Right Section (Sidebar, Export, Dark Mode)

    private var rightSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "sidebar.trailing", isSelected: false, action: {})
            ToolbarButton(icon: "square.and.arrow.up.fill", isSelected: false, action: {})
            ToolbarButton(
                icon: theme.isDarkMode ? "sun.max.fill" : "moon.fill",
                isSelected: theme.isDarkMode,
                action: { theme.isDarkMode.toggle() }
            )
        }
    }

    // MARK: - Divider

    private func makeDivider() -> some View {
        Text("|")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.5))
            .frame(width: 20)
    }

    // MARK: - Tutor Step Button

    private func stepButton(
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.9))
                .frame(width: 32, height: 32, alignment: .center)
                .background(
                    isActive
                        ? Color.white.opacity(0.25)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .frame(width: 32, height: 32)
        .buttonStyle(.plain)
    }

    // MARK: - Progress Bar

    private func fillColor(for progress: Double) -> Color {
        if progress < 0.5 {
            return .white.opacity(0.85)
        } else if progress < 0.8 {
            return Color(hex: 0xA8D5D5)
        } else {
            return Color(hex: 0x81C784)
        }
    }

    private func progressBar(progress: Double) -> some View {
        let barHeight: CGFloat = 12
        let cornerRadius: CGFloat = 4
        let shadowOffset: CGFloat = 1.5
        let isPending = currentTutorStep?.status == .idle || currentTutorStep?.status == .working

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .offset(x: shadowOffset, y: shadowOffset)

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.2))

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor(for: progress))
                    .frame(width: max(barHeight, geo.size.width * progress))
                    .opacity(isPending ? pulseOpacity : 1.0)
            }

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: barHeight / 2)

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .frame(width: 80, height: barHeight)
        .animation(.easeInOut(duration: 0.4), value: progress)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.5
            }
        }
    }
}
