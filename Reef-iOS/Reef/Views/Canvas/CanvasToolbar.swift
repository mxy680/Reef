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

struct PageMenuAnchorKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
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
    var hasActiveOverlay: Bool = false
    @Binding var pageOverlaySettings: PageOverlaySettings

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
                    answerKey: answerKey
                )
            } else {
                // Document name / question label
                Spacer()
                if isReconstructed && questionCount > 1 {
                    Text("Q\(visibleQuestionIndex + 1)")
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

            // Tutor toggle (right)
            if isReconstructed {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("", isOn: $tutorModeOn)
                        .toggleStyle(TutorToggleStyle())
                        .labelsHidden()
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
                        if selectedTool == tool && tool.hasSettings {
                            onToolRetapped(tool)
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTool = tool
                            }
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
                showPageSettings.toggle()
            })
            .overlay(alignment: .top) {
                if showPageSettings {
                    PageSettingsPopover(settings: $pageOverlaySettings)
                        .background(ReefColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ReefColors.black, lineWidth: 1.5)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ReefColors.black)
                                .offset(x: 4, y: 4)
                        )
                        .fixedSize()
                        .offset(y: 40)
                        .transition(.opacity)
                }
            }
            .zIndex(1)

            // Page menu button
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    showPageMenu.toggle()
                }
            } label: {
                Image("canvas.add_page")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(showPageMenu ? .white : Color.white.opacity(0.9))
                    .frame(width: 36, height: 36, alignment: .center)
                    .background(showPageMenu ? Color.white.opacity(0.25) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 36)
            .anchorPreference(key: PageMenuAnchorKey.self, value: .bounds) { $0 }
        }
    }

    // MARK: - AI Section (Mic + More)

    private var aiSection: some View {
        HStack(spacing: 0) {
            // Mic with status indicator
            ZStack(alignment: .topTrailing) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .offset(x: -2, y: 2)
            }
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
}

// MARK: - Tutor Step Row (inline in info strip)

private struct TutorStepRow: View {
    let questionIndex: Int
    let answerKey: QuestionAnswer?
    @State private var showHint = false
    @State private var showReveal = false
    @State private var pulseOpacity: Double = 1.0

    private var steps: [TutorStep] {
        guard let answerKey else { return [] }
        return TutorStepConverter.steps(from: answerKey)
    }

    /// First non-completed step, or the last step if all complete.
    private var currentStep: TutorStep? {
        steps.first(where: { $0.status != .completed }) ?? steps.last
    }

    /// Overall progress: fraction of completed steps.
    private var overallProgress: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter { $0.status == .completed }.count
        return Double(completed) / Double(steps.count)
    }

    var body: some View {
        if let step = currentStep {
            HStack(spacing: 0) {
                stepDivider()

                // Q label + progress bar
                HStack(spacing: 6) {
                    statusIcon(for: step.status)

                    Text("Q\(questionIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    progressBar(progress: overallProgress)
                }

                stepDivider()

                // Instruction text
                Text(step.instruction)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)

                stepDivider()

                // Hint button + popover
                stepButton(icon: "lightbulb.fill", isActive: showHint) {
                    showHint.toggle()
                    if showHint { showReveal = false }
                }
                .overlay(alignment: .bottom) {
                    if showHint {
                        tutorPopover(title: "Hint", text: step.hint)
                            .offset(y: 38)
                    }
                }
                .zIndex(showHint ? 10 : 0)

                // Reveal button + popover
                stepButton(icon: "eye.fill", isActive: showReveal) {
                    showReveal.toggle()
                    if showReveal { showHint = false }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showReveal {
                        tutorPopover(title: "Answer", text: step.work)
                            .offset(y: 38)
                    }
                }
                .zIndex(showReveal ? 10 : 0)
            }
            .animation(.spring(duration: 0.2), value: showHint)
            .animation(.spring(duration: 0.2), value: showReveal)
            .onChange(of: questionIndex) { _, _ in
                showHint = false
                showReveal = false
            }
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(.white.opacity(0.7))
                    .scaleEffect(0.65)
                Text("Loading...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
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
        let isPending = currentStep?.status == .pending

        return ZStack(alignment: .leading) {
            // Shadow
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .offset(x: shadowOffset, y: shadowOffset)

            // Track
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.2))

            // Fill
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor(for: progress))
                    .frame(width: max(barHeight, geo.size.width * progress))
                    .opacity(isPending ? pulseOpacity : 1.0)
            }

            // Top highlight
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: barHeight / 2)

            // Border
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

    // MARK: - Popover

    private func tutorPopover(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReefColors.black)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ReefColors.gray600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.black)
                .offset(x: 3, y: 3)
        )
        .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(for status: StepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        case .mistake:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: 0xE57373))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: 0x81C784))
        }
    }

    // MARK: - Button

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

    // MARK: - Divider

    private func stepDivider() -> some View {
        Text("|")
            .font(.system(size: 20, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.4))
            .frame(width: 16)
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isCustomIcon: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
            .frame(width: 36, height: 36, alignment: .center)
            .background(
                isSelected
                    ? Color.white.opacity(0.25)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }
}

// MARK: - Chrome Tab Shape

private struct ChromeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let curve: CGFloat = 8
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + curve, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - curve, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Page Menu View

struct PageMenuView: View {
    let onAction: (PageAction) -> Void
    var canUndo: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow(systemIcon: "doc.fill.badge.plus", label: "Add Page to End") {
                onAction(.addBlankAtEnd)
            }
            menuRow(systemIcon: "doc.on.doc.fill", label: "Add Page After This") {
                onAction(.addBlankAfterCurrent)
            }
            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            menuRow(systemIcon: "xmark.bin.fill", label: "Delete This Page", isDestructive: true) {
                onAction(.deleteCurrentPage)
            }
            menuRow(systemIcon: "trash.fill", label: "Delete All Pages", isDestructive: true) {
                onAction(.deleteAllPages)
            }
            if canUndo {
                Divider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 2)
                menuRow(systemIcon: "arrow.uturn.backward", label: "Undo") {
                    onAction(.undo)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: 230)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ReefColors.black, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ReefColors.black)
                .offset(x: 4, y: 4)
        )
    }

    private func menuRow(systemIcon: String, label: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundColor(isDestructive ? .red : ReefColors.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tutor Toggle Style

/// Custom toggle using only white/black opacity on the teal toolbar background.
private struct TutorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let trackWidth: CGFloat = 36
        let trackHeight: CGFloat = 20
        let knobSize: CGFloat = 16
        let knobPadding: CGFloat = 2

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn
                          ? Color.white.opacity(0.35)
                          : Color.black.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color.white.opacity(0.25),
                                lineWidth: 0.5
                            )
                    )
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
        }
        .buttonStyle(.plain)
    }
}
