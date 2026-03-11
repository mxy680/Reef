//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen scrollable PDF viewer with PencilKit drawing.
//  All questions render in a single scrollable view.
//

import SwiftUI
import UIKit
import PencilKit

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var viewModel = CanvasViewModel()
    @State private var selectedTool: CanvasTool = .pen
    @State private var tutorModeOn = true
    @State private var currentPageIndex = 0
    @State private var pageVersion = UUID()
    @State private var showPageMenu = false
    @State private var showRuler = false
    @State private var drawingManager: DrawingManager?
    @State private var penColor: UIColor = .black
    @State private var penWidth: CGFloat = 3.5
    @State private var showToolSettings = false
    @State private var selectedToolMidX: CGFloat = 0
    @State private var customColors: [UIColor] = []
    @State private var showColorPicker = false
    @State private var showPageSettings = false
    @State private var pageSettingsMidX: CGFloat = 0
    @State private var pageMenuMidX: CGFloat = 0
    @State private var pageOverlaySettings = PageOverlaySettings()
    @State private var answerKeys: [Int: QuestionAnswer] = [:]
    @State private var questionData: [Int: QuestionData] = [:]
    @State private var showTutorPopover = false
    @State private var activePartLabel: String?
    /// Writing-detected question index (overrides page-based detection)
    @State private var activeQuestionIndex: Int?
    @State private var transcriptionService = TranscriptionService()
    @State private var feedbackService = TutorFeedbackService()
    @State private var strokeCounts: [String: Int] = [:]

    private var isReconstructed: Bool {
        document.questionPages != nil
    }

    /// Page-based question index (fallback when no writing detected).
    private var pageBasedQuestionIndex: Int {
        guard let pages = document.questionPages else { return 0 }
        for (index, range) in pages.enumerated() {
            guard range.count == 2 else { continue }
            if currentPageIndex >= range[0] && currentPageIndex <= range[1] {
                return index
            }
        }
        return 0
    }

    /// The active question index — prefers writing-detected, falls back to page-based.
    private var visibleQuestionIndex: Int {
        activeQuestionIndex ?? pageBasedQuestionIndex
    }

    /// Current step index for the active subquestion (from feedback service).
    private var currentStepIndexForToolbar: Int {
        let subKey = "\(visibleQuestionIndex)-\(activePartLabel ?? "")"
        return feedbackService.currentStepIndices[subKey] ?? 0
    }

    /// Total step count for the active subquestion.
    private var totalStepCountForToolbar: Int {
        let qNum = visibleQuestionIndex + 1
        guard let answerKey = answerKeys[qNum] else { return 0 }
        let partLabel = activePartLabel ?? ""
        return stepsForPart(answerKey: answerKey, partLabel: partLabel).count
    }

    /// Current PencilKit tool derived from toolbar selection + settings
    private var currentPKTool: PKTool {
        selectedTool.pkTool(color: penColor, width: penWidth)
    }

    private static let cream = Color(hex: 0xF8F0E6)

    /// Tab strip = barColor (0x4E8A97) darkened 18% for safe area.
    /// RGB: (78,138,151) * 0.82 ≈ (64,113,124)
    private static let safeAreaColor = Color(red: 64/255.0, green: 113/255.0, blue: 124/255.0)

    private var canvasBackground: Color {
        theme.isDarkMode ? ReefColors.CanvasDark.background : Self.cream
    }

    private var canvasSafeArea: Color {
        theme.isDarkMode ? ReefColors.CanvasDark.safeArea : Self.safeAreaColor
    }

    var body: some View {
        ZStack {
            // Full-bleed tab strip teal so the safe area is never black
            canvasSafeArea.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(canvasBackground)
                        .transition(.opacity)
                } else if let error = viewModel.error {
                    errorView(error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(canvasBackground)
                        .transition(.opacity)
                } else if let pdf = viewModel.pdfDocument, let manager = drawingManager {
                    CanvasToolbar(
                        selectedTool: $selectedTool,
                        visibleQuestionIndex: visibleQuestionIndex,
                        onClose: {
                            manager.saveAll()
                            Task { await viewModel.saveIfNeeded() }
                            onDismiss()
                        },
                        tutorModeOn: $tutorModeOn,
                        isReconstructed: isReconstructed,
                        documentName: document.displayName,
                        answerKey: answerKeys[visibleQuestionIndex + 1],
                        questionCount: isReconstructed
                            ? (document.problemCount ?? 1)
                            : 1,
                        onPageAction: { handlePageAction($0) },
                        showPageMenu: $showPageMenu,
                        showRuler: $showRuler,
                        onUndo: { manager.undo() },
                        onRedo: { manager.redo() },
                        onToolRetapped: { _ in
                            showToolSettings = true
                        },
                        selectedToolMidX: $selectedToolMidX,
                        showPageSettings: $showPageSettings,
                        pageSettingsMidX: $pageSettingsMidX,
                        pageMenuMidX: $pageMenuMidX,
                        activePartLabel: activePartLabel,
                        hasActiveOverlay: pageOverlaySettings.type != .none,
                        pageOverlaySettings: $pageOverlaySettings,
                        showTutorPopover: $showTutorPopover,
                        stepProgressData: feedbackService.stepProgress,
                        currentStepIndex: currentStepIndexForToolbar,
                        totalStepCount: totalStepCountForToolbar,
                        onAdvanceStep: {
                            feedbackService.advanceStep(
                                questionIndex: visibleQuestionIndex,
                                partLabel: activePartLabel ?? ""
                            )
                        }
                    )
                    .zIndex(1)
                    .overlay(alignment: .bottomLeading) {
                        if showToolSettings {
                            GeometryReader { geo in
                                let containerMinX = geo.frame(in: .global).minX
                                let containerWidth = geo.size.width
                                let popoverWidth: CGFloat = 190
                                let idealX = selectedToolMidX - containerMinX - popoverWidth / 2
                                let clampedX = max(12, min(idealX, containerWidth - popoverWidth - 12))
                                let arrowOffset = (selectedToolMidX - containerMinX) - (clampedX + popoverWidth / 2)

                                PopoverCard(arrowOffset: arrowOffset) {
                                    ToolSettingsPopover(
                                        selectedColor: $penColor,
                                        lineWidth: $penWidth,
                                        customColors: $customColors,
                                        onAddColorTapped: { showColorPicker = true }
                                    )
                                }
                                .transition(.scale(scale: 0.01, anchor: .top))
                                .offset(x: clampedX)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showToolSettings)
                    .overlay(alignment: .bottomLeading) {
                        if showPageSettings {
                            GeometryReader { geo in
                                let containerMinX = geo.frame(in: .global).minX
                                let containerWidth = geo.size.width
                                let popoverWidth: CGFloat = 280
                                let idealX = pageSettingsMidX - containerMinX - popoverWidth / 2
                                let clampedX = max(12, min(idealX, containerWidth - popoverWidth - 12))
                                let arrowOffset = (pageSettingsMidX - containerMinX) - (clampedX + popoverWidth / 2)

                                PopoverCard(arrowOffset: arrowOffset, maxWidth: popoverWidth) {
                                    PageSettingsPopover(settings: $pageOverlaySettings)
                                }
                                .transition(.scale(scale: 0.01, anchor: .top))
                                .offset(x: clampedX)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showPageSettings)
                    .overlay(alignment: .bottomLeading) {
                        if showPageMenu {
                            GeometryReader { geo in
                                let containerMinX = geo.frame(in: .global).minX
                                let containerWidth = geo.size.width
                                let popoverWidth: CGFloat = 230
                                let idealX = pageMenuMidX - containerMinX - popoverWidth / 2
                                let clampedX = max(12, min(idealX, containerWidth - popoverWidth - 12))
                                let arrowOffset = (pageMenuMidX - containerMinX) - (clampedX + popoverWidth / 2)

                                PopoverCard(arrowOffset: arrowOffset, maxWidth: popoverWidth) {
                                    PageMenuView(onAction: { action in
                                        showPageMenu = false
                                        handlePageAction(action)
                                    }, canUndo: viewModel.canUndo)
                                }
                                .transition(.scale(scale: 0.01, anchor: .top))
                                .offset(x: clampedX)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showPageMenu)
                    .zIndex(2)

                    ZStack(alignment: .top) {
                        CanvasPageView(
                            pdfDocument: pdf,
                            pageRange: nil,
                            drawingManager: manager,
                            currentTool: currentPKTool,
                            onVisiblePageChanged: { currentPageIndex = $0 },
                            onWritingPositionChanged: { pageIndex, yPDFPoints in
                                updateActivePartFromWriting(pageIndex: pageIndex, yPDFPoints: yPDFPoints)
                            },
                            onNewPenStroke: { pageIndex, yPDFPoints in
                                handleNewPenStroke(pageIndex: pageIndex, yPDFPoints: yPDFPoints)
                            },
                            onStrokesErased: { pageIndex in
                                handleStrokesErased(pageIndex: pageIndex)
                            },
                            darkMode: theme.isDarkMode,
                            overlaySettings: pageOverlaySettings
                        )
                        .id(pageVersion)

                        if showRuler {
                            RulerOverlayView()
                                .transition(.opacity)
                        }

                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let partLabel = activePartLabel {
                            let key = "\(visibleQuestionIndex)-\(partLabel)"
                            TranscriptionDebugPanel(
                                questionIndex: visibleQuestionIndex,
                                partLabel: partLabel,
                                latex: transcriptionService.transcriptions[key]
                            )
                            .padding(16)
                        }
                    }
                    .background(canvasBackground)
                    .overlay {
                        // Tap-to-dismiss layer (covers canvas only, not toolbar)
                        if showToolSettings || showPageSettings || showPageMenu {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showToolSettings = false
                                    showPageSettings = false
                                    showPageMenu = false
                                }
                        }
                        if showTutorPopover {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showTutorPopover = false }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.25), value: tutorModeOn)
            .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: theme.isDarkMode)
            .animation(.easeInOut(duration: 0.2), value: showRuler)

            // Centered color picker popup
            if showColorPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showColorPicker = false }

                AddColorPopup(
                    onAdd: { color in
                        customColors.append(color)
                        penColor = color
                        showColorPicker = false
                    },
                    onDismiss: { showColorPicker = false }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: showColorPicker)
        .animation(.spring(duration: 0.2), value: showPageSettings)
        .ignoresSafeArea()
        .task {
            #if DEBUG
            if document.id == "dev-test" {
                viewModel.loadTestDocument()
                let manager = DrawingManager(documentId: "dev-test")
                manager.loadAll(pageCount: 1)
                drawingManager = manager
                // Seed fake answer keys so tutor popovers can be tested
                answerKeys = [1: QuestionAnswer(
                    questionNumber: 1,
                    steps: [
                        AnswerKeyStep(
                            description: "Set up the equation",
                            explanation: "Start by isolating the variable on one side. Move all terms with x to the left and constants to the right.",
                            work: "Given $2x + 5 = 13$, subtract 5 from both sides:\n$2x = 8$\nDivide by 2:\n$x = 4$"
                        )
                    ],
                    finalAnswer: "$x = 4$",
                    parts: []
                )]
                return
            }
            #endif
            await viewModel.loadDocument(document)
            if let pdf = viewModel.pdfDocument {
                let manager = DrawingManager(documentId: document.id)
                manager.loadAll(pageCount: pdf.pageCount)
                drawingManager = manager
            }
            if isReconstructed {
                let result = await AnswerKeyService.shared.fetchAnswerKeys(documentId: document.id)
                answerKeys = result.answers
                questionData = result.questions
                setDefaultPartLabel(for: visibleQuestionIndex)
            }
        }
        .onChange(of: selectedTool) { _, newTool in
            if !newTool.hasSettings {
                showToolSettings = false
            }
        }
        .onChange(of: showToolSettings) { _, isShowing in
            if isShowing { showPageSettings = false; showPageMenu = false }
        }
        .onChange(of: showPageSettings) { _, isShowing in
            if isShowing { showToolSettings = false; showPageMenu = false }
        }
        .onChange(of: showPageMenu) { _, isShowing in
            if isShowing { showToolSettings = false; showPageSettings = false }
        }
        .onChange(of: pageBasedQuestionIndex) { _, newIndex in
            // When user scrolls to a different page-based question, reset writing-detected state
            activeQuestionIndex = nil
            setDefaultPartLabel(for: newIndex)
        }
        .onChange(of: transcriptionService.transcriptions) { _, newTranscriptions in
            guard tutorModeOn else { return }
            let qi = visibleQuestionIndex
            let partLabel = activePartLabel ?? ""
            let key = "\(qi)-\(partLabel)"
            guard let latex = newTranscriptions[key] else { return }

            // Get question text from questionData
            let qNum = qi + 1  // 1-based
            let questionText: String
            if partLabel.isEmpty {
                questionText = questionData[qNum]?.text ?? ""
            } else {
                questionText = questionData[qNum]?.textForPart(partLabel) ?? ""
            }

            // Get steps for the current part
            guard let answerKey = answerKeys[qNum] else { return }
            let partSteps = stepsForPart(answerKey: answerKey, partLabel: partLabel)

            feedbackService.onTranscriptionChanged(
                questionIndex: qi,
                partLabel: partLabel,
                latex: latex,
                questionText: questionText,
                steps: partSteps,
                strokeCount: strokeCounts[key] ?? 0
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            drawingManager?.saveAll()
        }
        .onDisappear {
            Task { await viewModel.saveIfNeeded() }
        }
    }

    // MARK: - Active Part Detection

    /// Match a writing position to a subquestion region and update both active question and part.
    private func updateActivePartFromWriting(pageIndex: Int, yPDFPoints: Double) {
        guard let regions = document.questionRegions,
              let questionPages = document.questionPages else { return }

        // Search across ALL questions' regions to find the match
        for (qi, range) in questionPages.enumerated() {
            guard range.count == 2,
                  pageIndex >= range[0] && pageIndex <= range[1],
                  qi < regions.count,
                  let regionData = regions[qi] else { continue }

            let localPage = pageIndex - range[0]

            for region in regionData.regions {
                if region.page == localPage &&
                   yPDFPoints >= region.yStart &&
                   yPDFPoints <= region.yEnd {
                    if activeQuestionIndex != qi {
                        activeQuestionIndex = qi
                    }
                    if activePartLabel != region.label {
                        activePartLabel = region.label
                    }
                    return
                }
            }

            // Page is within this question but no region matched.
            // If the question has subquestion regions, the user is annotating
            // (writing above/between parts) — nil out the part label.
            if !regionData.regions.isEmpty {
                if activeQuestionIndex != qi { activeQuestionIndex = qi }
                activePartLabel = nil
                return
            }
        }
    }

    // MARK: - Stroke Transcription

    /// Collect all pen strokes in the active subquestion region and send for transcription.
    /// Does its own region lookup from pageIndex + yPDFPoints (can't rely on @State which
    /// hasn't propagated yet when both callbacks fire in the same delegate call).
    private func handleNewPenStroke(pageIndex: Int, yPDFPoints: Double) {
        guard let regions = document.questionRegions,
              let questionPages = document.questionPages,
              let manager = drawingManager else { return }

        // Find which question and part this stroke belongs to
        var matchedQI: Int?
        var matchedPartLabel: String?

        for (qi, range) in questionPages.enumerated() {
            guard range.count == 2,
                  pageIndex >= range[0] && pageIndex <= range[1],
                  qi < regions.count,
                  let regionData = regions[qi] else { continue }

            let localPage = pageIndex - range[0]

            for region in regionData.regions {
                if region.page == localPage &&
                   yPDFPoints >= region.yStart &&
                   yPDFPoints <= region.yEnd {
                    matchedQI = qi
                    matchedPartLabel = region.label
                    break
                }
            }

            // If we're in this question's page range but no region matched,
            // and the question has subquestion regions, this is annotation — skip.
            if matchedPartLabel == nil && !regionData.regions.isEmpty {
                print("[Transcription] Annotation area — skipping")
                return
            }
            break
        }

        guard let qi = matchedQI, let partLabel = matchedPartLabel else {
            print("[Transcription] No matching region for page=\(pageIndex) y=\(yPDFPoints)")
            return
        }

        guard questionPages[qi].count == 2,
              let regionData = regions[qi] else { return }

        let startPage = questionPages[qi][0]
        let endPage = questionPages[qi][1]

        // Find all PartRegions matching the active label (may span multiple pages)
        let matchingRegions = regionData.regions.filter { $0.label == partLabel }
        guard !matchingRegions.isEmpty else { return }

        // Collect all pen strokes that fall within matching regions
        var allStrokes: [[(x: Double, y: Double)]] = []

        for absPage in startPage...endPage {
            let localPage = absPage - startPage
            let pageRegions = matchingRegions.filter { $0.page == localPage }
            guard !pageRegions.isEmpty else { continue }

            let drawing = manager.drawing(for: absPage)
            for stroke in drawing.strokes {
                // Only pen strokes, not diagram (monoline)
                guard stroke.ink.inkType == .pen else { continue }

                // Use the stroke's midpoint Y to determine if it's in the region
                let bounds = stroke.renderBounds
                let midY = bounds.midY / 2.0  // Convert canvas coords to PDF points

                let inRegion = pageRegions.contains { region in
                    midY >= region.yStart && midY <= region.yEnd
                }
                guard inRegion else { continue }

                // Extract points from the stroke path (canvas scale, not PDF points)
                var points: [(x: Double, y: Double)] = []
                for i in stride(from: 0, to: stroke.path.count, by: 1) {
                    let loc = stroke.path[i].location
                    points.append((x: Double(loc.x), y: Double(loc.y)))
                }
                if !points.isEmpty {
                    allStrokes.append(points)
                }
            }
        }

        // Normalize: translate all strokes so bounding box starts at (0,0)
        if !allStrokes.isEmpty {
            var minX = Double.infinity, minY = Double.infinity
            for stroke in allStrokes {
                for pt in stroke {
                    minX = min(minX, pt.x)
                    minY = min(minY, pt.y)
                }
            }
            allStrokes = allStrokes.map { stroke in
                stroke.map { (x: $0.x - minX, y: $0.y - minY) }
            }
        }

        let key = "\(qi)-\(partLabel)"
        strokeCounts[key] = allStrokes.count

        print("[Transcription] Q\(qi+1)(\(partLabel)): sending \(allStrokes.count) strokes")
        transcriptionService.transcribe(
            questionIndex: qi,
            partLabel: partLabel,
            strokes: allStrokes
        )
    }

    /// Re-transcribe after strokes are erased, using the current active question/part.
    private func handleStrokesErased(pageIndex: Int) {
        guard let partLabel = activePartLabel else { return }

        let qi = visibleQuestionIndex
        guard let regions = document.questionRegions,
              let questionPages = document.questionPages,
              let manager = drawingManager,
              qi < regions.count,
              qi < questionPages.count,
              questionPages[qi].count == 2,
              let regionData = regions[qi] else { return }

        let startPage = questionPages[qi][0]
        let endPage = questionPages[qi][1]
        let matchingRegions = regionData.regions.filter { $0.label == partLabel }
        guard !matchingRegions.isEmpty else { return }

        // Collect remaining pen strokes in the region
        var allStrokes: [[(x: Double, y: Double)]] = []

        for absPage in startPage...endPage {
            let localPage = absPage - startPage
            let pageRegions = matchingRegions.filter { $0.page == localPage }
            guard !pageRegions.isEmpty else { continue }

            let drawing = manager.drawing(for: absPage)
            for stroke in drawing.strokes {
                guard stroke.ink.inkType == .pen else { continue }
                let midY = stroke.renderBounds.midY / 2.0
                let inRegion = pageRegions.contains { $0.yStart <= midY && midY <= $0.yEnd }
                guard inRegion else { continue }

                var points: [(x: Double, y: Double)] = []
                for i in stride(from: 0, to: stroke.path.count, by: 1) {
                    let loc = stroke.path[i].location
                    points.append((x: Double(loc.x), y: Double(loc.y)))
                }
                if !points.isEmpty { allStrokes.append(points) }
            }
        }

        // Normalize
        if !allStrokes.isEmpty {
            var minX = Double.infinity, minY = Double.infinity
            for stroke in allStrokes { for pt in stroke { minX = min(minX, pt.x); minY = min(minY, pt.y) } }
            allStrokes = allStrokes.map { $0.map { (x: $0.x - minX, y: $0.y - minY) } }
        }

        let key = "\(qi)-\(partLabel)"
        strokeCounts[key] = allStrokes.count

        print("[Transcription] Q\(qi+1)(\(partLabel)): erased → re-sending \(allStrokes.count) strokes")

        if allStrokes.isEmpty {
            // All strokes erased — clear transcription
            transcriptionService.transcriptions[key] = nil
        } else {
            transcriptionService.transcribe(questionIndex: qi, partLabel: partLabel, strokes: allStrokes)
        }
    }

    /// Set the default active part label for the given question index.
    private func setDefaultPartLabel(for questionIndex: Int) {
        guard let regions = document.questionRegions,
              questionIndex < regions.count,
              let regionData = regions[questionIndex] else {
            activePartLabel = nil
            return
        }
        activePartLabel = regionData.regions.first?.label
    }

    // MARK: - Step Lookup

    private func stepsForPart(answerKey: QuestionAnswer, partLabel: String) -> [AnswerKeyStep] {
        if partLabel.isEmpty || answerKey.parts.isEmpty { return answerKey.steps }
        return findPartSteps(partLabel, in: answerKey.parts) ?? []
    }

    private func findPartSteps(_ label: String, in parts: [PartAnswer]) -> [AnswerKeyStep]? {
        for part in parts {
            if part.label == label { return part.steps }
            if let found = findPartSteps(label, in: part.parts) { return found }
        }
        return nil
    }

    // MARK: - Page Actions

    private func handlePageAction(_ action: PageAction) {
        switch action {
        case .addBlankAtEnd:
            viewModel.addBlankPage(at: viewModel.pageCount)
        case .addBlankAfterCurrent:
            viewModel.addBlankPage(at: currentPageIndex + 1)
        case .deleteCurrentPage:
            viewModel.deletePageAt(currentPageIndex)
            if currentPageIndex >= viewModel.pageCount {
                currentPageIndex = max(0, viewModel.pageCount - 1)
            }
        case .deleteAllPages:
            viewModel.deleteAllPages()
            currentPageIndex = 0
        case .undo:
            if viewModel.undo() {
                currentPageIndex = min(currentPageIndex, max(0, viewModel.pageCount - 1))
            }
        }
        pageVersion = UUID()
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Document skeleton placeholder
            VStack(spacing: 0) {
                // Page shape with ruled lines + shimmer
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    // Ruled lines
                    GeometryReader { geo in
                        let lineCount = 14
                        let topInset = geo.size.height * 0.12
                        let spacing = (geo.size.height * 0.72) / CGFloat(lineCount)
                        let hPad = geo.size.width * 0.12

                        ForEach(0..<lineCount, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(ReefColors.gray100)
                                .frame(
                                    width: i == 0
                                        ? (geo.size.width - hPad * 2) * 0.6
                                        : (geo.size.width - hPad * 2) * CGFloat([1.0, 0.92, 0.85, 1.0, 0.78, 0.95, 1.0, 0.88, 0.7, 1.0, 0.93, 0.82, 0.96, 0.6][i % 14]),
                                    height: 4
                                )
                                .offset(x: hPad, y: topInset + CGFloat(i) * spacing)
                        }
                    }

                    ShimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 200, height: 260)
            }

            Spacer().frame(height: 28)

            // Document name
            Text(document.displayName)
                .font(.epilogue(16, weight: .semiBold))
                .tracking(-0.04 * 16)
                .foregroundStyle(ReefColors.black)
                .lineLimit(1)

            Spacer().frame(height: 10)

            // Subtle loading indicator
            HStack(spacing: 8) {
                ProgressView()
                    .tint(ReefColors.primary)
                    .scaleEffect(0.8)

                Text("Opening...")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.gray500)
            }

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(ReefColors.gray400)

            Text(message)
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(ReefColors.gray600)

            Text("Go Back")
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(ReefColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { onDismiss() }
        }
    }
}
