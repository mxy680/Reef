import SwiftUI
import PencilKit
import PDFKit
import UIKit

// MARK: - Canvas ViewModel

@Observable
@MainActor
final class CanvasViewModel {
    let document: Document

    // MARK: - PDF

    var pdfDocument: PDFDocument
    var isLoadingPDF: Bool = false
    var pdfError: String?

    // MARK: - Tool State

    let drawingManager = CanvasDrawingManager()
    var selectedTool: CanvasToolType = .pen
    var penColor: UIColor = .black
    var penWidth: CGFloat = 2.0
    var highlighterColor: UIColor = UIColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1)
    var highlighterWidth: CGFloat = 4.0
    var shapesColor: UIColor = .black
    var shapesWidth: CGFloat = 2.0
    var eraserMode: PKEraserTool.EraserType = .vector
    var eraserWidth: CGFloat = 8.0
    var customColors: [UIColor] = []
    var customHighlighterColors: [UIColor] = []
    var customShapesColors: [UIColor] = []

    /// The active PKTool derived from current settings.
    var activePKTool: PKTool {
        let color: UIColor
        let width: CGFloat
        switch selectedTool {
        case .highlighter:
            color = highlighterColor
            width = highlighterWidth
        case .shapes:
            color = shapesColor
            width = shapesWidth
        default:
            color = penColor
            width = penWidth
        }
        return selectedTool.pkTool(
            color: color,
            width: width,
            eraserType: eraserMode,
            eraserWidth: eraserWidth
        )
    }

    var activeDrawingPolicy: PKCanvasViewDrawingPolicy {
        // The iOS Simulator does not support Apple Pencil input. Using `.anyInput` allows
        // touch/mouse drawing during development so the canvas is testable without real hardware.
        // On device, only Pencil input is accepted (unless the hand-draw tool is active).
        #if targetEnvironment(simulator)
        return .anyInput
        #else
        return selectedTool == .handDraw ? .anyInput : .pencilOnly
        #endif
    }

    // MARK: - Page State

    var currentPageIndex: Int = 0
    var pageVersion: Int = 0
    var zoomScale: CGFloat = 1.0
    var overlaySettings: CanvasOverlaySettings = CanvasOverlaySettings()
    var originalPageCount: Int = 0
    var addedPageIndices: [Int] = []
    private var savedState: CanvasDocumentData?

    var pageCount: Int {
        pdfDocument.pageCount
    }

    // MARK: - Battery

    // MARK: - Study Timer

    var studySeconds: Int = 0
    private let sessionStart = Date()

    var studyTimerLabel: String {
        let h = studySeconds / 3600
        let m = (studySeconds % 3600) / 60
        let s = studySeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func tickStudyTimer() {
        studySeconds = Int(Date().timeIntervalSince(sessionStart))
    }

    var batteryLevel: Float = 1.0

    var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }

    /// Asset name for the battery icon based on current level.
    var batteryIconName: String {
        switch batteryLevel {
        case ..<0.15: "battery.1"
        case ..<0.40: "battery.2"
        case ..<0.70: "battery.3"
        default:       "battery.4"
        }
    }

    func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = max(UIDevice.current.batteryLevel, 0)
        // On simulator batteryLevel is -1; show full
        if batteryLevel < 0 { batteryLevel = 1.0 }
    }

    func updateBatteryLevel() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level >= 0 ? level : 1.0
    }

    // MARK: - UI State

    var showPageControls: Bool = false
    var showRuler: Bool = false
    var isDarkMode: Bool = false
    var showSidebar: Bool = false
    var activeQuestionLabel: String?
    var isMicOn: Bool = false
    var showCalculator: Bool = false
    let calculatorViewModel = CalculatorViewModel()
    let handwritingService = HandwritingTranscriptionService()
    let tutorEvalService = TutorEvaluationService()
    var showClearConfirmation: Bool = false
    var isExporting: Bool = false
    var exportedPDFData: Data?
    var exportedPDFURL: URL?
    var showExportPreview: Bool = false
    weak var containerView: CanvasContainerView?

    // MARK: - Popover State

    var showToolSettings: Bool = false
    var showEraserSettings: Bool = false
    var showPageSettings: Bool = false
    var showPageMenu: Bool = false
    var showAddColor: Bool = false

    // Popover anchor positions (global midX)
    var selectedToolMidX: CGFloat = 0
    var pageSettingsMidX: CGFloat = 0
    var pageMenuMidX: CGFloat = 0

    // MARK: - Connection State

    var isWifiConnected: Bool = false
    private var wifiTask: Task<Void, Never>?

    func startWifiMonitoring() {
        isWifiConnected = WifiMonitor.shared.isConnected
        wifiTask?.cancel()
        wifiTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { break }
                self.isWifiConnected = WifiMonitor.shared.isConnected
            }
        }
    }

    // MARK: - Tutor State

    var tutorModeOn: Bool = false
    var currentTutorStepIndex: Int = 0
    var currentQuestionIndex: Int = 0
    var showHintPopover: Bool = false
    var showRevealPopover: Bool = false
    var hintMidX: CGFloat = 0
    var revealMidX: CGFloat = 0

    // Answer key data
    var answerKeys: [Int: QuestionAnswer] = [:]
    var isLoadingAnswerKeys: Bool = false
    private var savedTutorProgress: [String: TutorStepState]?

    /// Whether this document has been reconstructed (has answer keys available)
    var isReconstructed: Bool {
        document.problemCount != nil && (document.problemCount ?? 0) > 0
    }

    var currentAnswerKey: QuestionAnswer? {
        answerKeys[currentQuestionIndex + 1] // 1-based question numbers
    }

    var currentSteps: [AnswerKeyStep] {
        guard let ak = currentAnswerKey else { return [] }
        // If the question has parts, show steps from the first part
        if let firstPart = ak.parts.first, !firstPart.steps.isEmpty {
            return firstPart.steps
        }
        return ak.steps
    }

    var tutorStepCount: Int { currentSteps.count }

    var currentHintStep: AnswerKeyStep? {
        guard currentTutorStepIndex < currentSteps.count else { return nil }
        return currentSteps[currentTutorStepIndex]
    }

    var currentTutorStepLabel: String {
        guard currentTutorStepIndex < currentSteps.count else { return "" }
        return currentSteps[currentTutorStepIndex].description
    }

    var tutorProgress: Double {
        guard tutorStepCount > 0 else { return 0 }
        let completedSteps = Double(currentTutorStepIndex)
        let intraStepProgress = tutorEvalService.stepProgress
        return (completedSteps + intraStepProgress) / Double(tutorStepCount)
    }

    func loadAnswerKeys() async {
        guard isReconstructed else { return }
        isLoadingAnswerKeys = true
        let repo = SupabaseAnswerKeyRepository()
        let result = await repo.fetchAnswerKeys(documentId: document.id)
        answerKeys = result.answers
        isLoadingAnswerKeys = false
        tutorModeOn = !answerKeys.isEmpty
        if tutorModeOn {
            showSidebar = true
            // Restore tutor state for the active question (or default Q1a)
            let label = activeQuestionLabel ?? "Q1a"
            restoreTutorStateForLabel(label)
        }
    }

    // MARK: - Toolbar Layout

    var toolbarRowMinX: CGFloat = 0
    var toolbarRowWidth: CGFloat = 0

    // MARK: - Init

    init(document: Document) {
        self.document = document
        self.pdfDocument = MockCanvasData.blankPDF()
        let loaded = CanvasStorageService.load(documentId: document.id)
        self.savedState = loaded
        self.savedTutorProgress = loaded?.tutorProgress

        tutorEvalService.onStepCompleted = { [weak self] in
            guard let self else { return }
            self.advanceTutorStep()
        }

        handwritingService.onLatexChanged = { [weak self] _ in
            guard let self else { return }
            self.triggerTutorEvaluation()
        }

        Task { await loadPDF() }
        Task { await loadAnswerKeys() }
    }

    private static let pdfSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    private func loadPDF() async {
        isLoadingPDF = true
        pdfError = nil
        do {
            let repo = SupabaseDocumentRepository()
            let signedURL = try await repo.getDownloadURL(document.id)
            let (data, _) = try await Self.pdfSession.data(from: signedURL)
            guard let pdf = PDFDocument(data: data) else {
                pdfError = "Unable to open PDF"
                isLoadingPDF = false
                return
            }
            pdfDocument = pdf
            originalPageCount = pdf.pageCount

            if let saved = savedState {
                print("[CanvasVM] Restoring: \(saved.drawingDataByPage.count) drawings, overlay=\(saved.overlaySettings.type.rawValue)")
                overlaySettings = saved.overlaySettings
                currentPageIndex = min(saved.currentPageIndex, pdf.pageCount - 1)

                // Restore added blank pages in ascending index order
                for index in saved.addedPageIndices.sorted() {
                    if index <= pdfDocument.pageCount {
                        let blankPage = createBlankPage()
                        pdfDocument.insert(blankPage, at: index)
                    }
                }
                addedPageIndices = saved.addedPageIndices

                // Restore per-page drawings (suppress onDrawingChanged to avoid re-saving)
                let savedCallback = drawingManager.onDrawingChanged
                drawingManager.onDrawingChanged = nil
                for (key, data) in saved.drawingDataByPage {
                    guard let pageIndex = Int(key) else { continue }
                    do {
                        let drawing = try PKDrawing(data: data)
                        drawingManager.setDrawing(drawing, for: pageIndex)
                    } catch {
                        print("[CanvasVM] Failed to decode drawing for page \(pageIndex): \(error)")
                    }
                }
                drawingManager.onDrawingChanged = savedCallback
                print("[CanvasVM] Restored \(saved.drawingDataByPage.count) drawings")

                savedState = nil
            }

            // Single pageVersion bump AFTER all state is restored
            // so setupPages reads the restored drawings
            pageVersion += 1
        } catch {
            pdfError = "Failed to download document"
        }
        isLoadingPDF = false
    }

    // MARK: - Question Region Detection

    func updateActiveQuestion(pageIndex: Int, yPosition: Double) {
        // Update current page index so region filtering uses the correct page
        currentPageIndex = pageIndex

        let originalPage = originalPageIndex(for: pageIndex)
        let newLabel = QuestionRegionTracker.activeLabel(
            forPage: originalPage,
            yPosition: yPosition,
            questionRegions: document.questionRegions,
            questionPages: document.questionPages
        )

        // On question change: save current state, restore new question's state
        if newLabel != activeQuestionLabel {
            // Save outgoing question's tutor state
            if let oldLabel = activeQuestionLabel, tutorModeOn {
                saveTutorStateForLabel(oldLabel)
            }

            handwritingService.latexResult = ""
            activeQuestionLabel = newLabel

            // Restore incoming question's tutor state
            if let label = newLabel {
                restoreTutorStateForLabel(label)
            }
        }
    }

    /// Save current tutor state into the in-memory cache for a given label.
    private func saveTutorStateForLabel(_ label: String) {
        if savedTutorProgress == nil { savedTutorProgress = [:] }
        savedTutorProgress?[label] = TutorStepState(
            currentStepIndex: currentTutorStepIndex,
            stepEvaluations: [StepEvaluation(
                progress: tutorEvalService.stepProgress,
                status: tutorEvalService.status,
                mistakeExplanation: tutorEvalService.mistakeExplanation
            )],
            lastTranscription: handwritingService.latexResult
        )
    }

    /// Restore tutor state from saved data for a given label.
    private func restoreTutorStateForLabel(_ label: String) {
        guard let state = savedTutorProgress?[label] else {
            // No saved state — reset to beginning
            currentTutorStepIndex = 0
            tutorEvalService.resetForNextStep()
            return
        }

        currentTutorStepIndex = min(state.currentStepIndex, max(0, tutorStepCount - 1))

        if let eval = state.stepEvaluations.first {
            tutorEvalService.stepProgress = eval.progress
            tutorEvalService.status = eval.status
            tutorEvalService.mistakeExplanation = eval.mistakeExplanation
        }

        if !state.lastTranscription.isEmpty {
            handwritingService.latexResult = state.lastTranscription
        }
    }

    /// Returns only the active SUBquestion's regions for stroke filtering.
    /// e.g. if activeQuestionLabel is "Q2a", returns only regions with label "a" for Q2.
    func activeSubquestionRegions() -> [PartRegion]? {
        guard let label = activeQuestionLabel,
              let qPages = document.questionPages,
              let qRegions = document.questionRegions else { return nil }

        // Parse "Q2a" → questionIndex=1, partLabel="a"
        // Format: Q<number><label>
        guard label.hasPrefix("Q"), label.count >= 3 else { return nil }
        let numAndLabel = label.dropFirst() // "2a"
        var numStr = ""
        var partLabel = ""
        for ch in numAndLabel {
            if ch.isNumber {
                numStr.append(ch)
            } else {
                partLabel.append(ch)
            }
        }
        guard let qNum = Int(numStr), qNum >= 1 else { return nil }
        let qi = qNum - 1

        guard qi < qPages.count, qi < qRegions.count,
              let data = qRegions[qi] else { return nil }

        // Filter to only the matching part label (or nil for stem)
        let targetLabel = partLabel.isEmpty ? nil : partLabel
        return data.regions.filter { $0.label == targetLabel }
    }

    /// Map current page index back to original index, accounting for added blank pages.
    private func originalPageIndex(for currentIndex: Int) -> Int {
        let addedBefore = addedPageIndices.filter { $0 <= currentIndex }.count
        return currentIndex - addedBefore
    }

    // MARK: - Actions

    func dismissAllPopovers() {
        showToolSettings = false
        showEraserSettings = false
        showPageSettings = false
        showPageMenu = false
        showHintPopover = false
        showRevealPopover = false
        showPageControls = false
    }

    func exportDocument() {
        guard !isExporting, let container = containerView else { return }
        isExporting = true

        // If dark mode, temporarily switch to light for export
        let wasDarkMode = isDarkMode
        if wasDarkMode {
            isDarkMode = false
            container.applyDarkMode(false)
        }

        // Screenshot each page — WYSIWYG, no coordinate math
        let data = CanvasExportService.exportFromContainer(container)

        // Restore dark mode
        if wasDarkMode {
            isDarkMode = true
            container.applyDarkMode(true)
        }

        exportedPDFData = data
        showExportPreview = true
        isExporting = false
    }

    func shareExportedPDF() {
        guard let data = exportedPDFData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(document.displayName).pdf")
        try? data.write(to: tempURL)
        exportedPDFURL = tempURL
    }

    func dismissExportPreview() {
        showExportPreview = false
        exportedPDFData = nil
        exportedPDFURL = nil
    }

    func toolRetapped(_ tool: CanvasToolType) {
        dismissAllPopovers()
        if tool == .eraser {
            showEraserSettings = true
        } else if tool.hasSettings {
            showToolSettings = true
        }
    }

    func advanceTutorStep() {
        guard currentTutorStepIndex < tutorStepCount - 1 else { return }
        currentTutorStepIndex += 1
        // Don't dismiss hint/reveal — user closes them manually via X button
        tutorEvalService.resetForNextStep()
    }

    func resetTutorSteps() {
        currentTutorStepIndex = 0
        showHintPopover = false
        showRevealPopover = false
        tutorEvalService.reset()
    }

    /// Trigger AI evaluation of the current student work.
    func triggerTutorEvaluation() {
        NSLog("[TutorEval] triggerTutorEvaluation called — tutorModeOn=\(tutorModeOn), latex=\(handwritingService.latexResult.prefix(40)), activeQ=\(activeQuestionLabel ?? "nil")")

        guard tutorModeOn,
              !handwritingService.latexResult.isEmpty else {
            NSLog("[TutorEval] Skipped: tutorModeOn=\(tutorModeOn), latexEmpty=\(handwritingService.latexResult.isEmpty)")
            return
        }

        // If no active question label, use Q1a as default for reconstructed docs
        let label = activeQuestionLabel ?? "Q1a"

        // Parse "Q2a" → questionNumber=2, partLabel="a"
        guard label.hasPrefix("Q"), label.count >= 2 else { return }
        let numAndLabel = label.dropFirst()
        var numStr = ""
        var partLabel = ""
        for ch in numAndLabel {
            if ch.isNumber {
                numStr.append(ch)
            } else {
                partLabel.append(ch)
            }
        }
        guard let qNum = Int(numStr) else { return }

        NSLog("[TutorEval] Evaluating Q\(qNum)\(partLabel) step \(currentTutorStepIndex) with latex: \(handwritingService.latexResult.prefix(60))")

        tutorEvalService.evaluate(
            latex: handwritingService.latexResult,
            documentId: document.id,
            questionNumber: qNum,
            partLabel: partLabel.isEmpty ? nil : partLabel,
            stepIndex: currentTutorStepIndex
        )
    }

    // MARK: - Page Mutations

    func addBlankPageAtEnd(drawingManager: CanvasDrawingManager) {
        let insertIndex = pdfDocument.pageCount
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        addedPageIndices.append(insertIndex)
        pageVersion += 1
    }

    func addBlankPageAfterCurrent(drawingManager: CanvasDrawingManager) {
        let insertIndex = currentPageIndex + 1
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        // Shift any tracked added indices that are >= insertIndex
        addedPageIndices = addedPageIndices.map { $0 >= insertIndex ? $0 + 1 : $0 }
        addedPageIndices.append(insertIndex)
        pageVersion += 1
    }

    func clearAllStrokes() {
        guard let container = containerView else { return }
        let savedCallback = drawingManager.onDrawingChanged
        drawingManager.onDrawingChanged = nil
        for i in 0..<container.canvasViews.count {
            drawingManager.setDrawing(PKDrawing(), for: i)
            container.canvasViews[i].drawing = PKDrawing()
        }
        drawingManager.onDrawingChanged = savedCallback
        drawingManager.onDrawingChanged?()
    }

    func deleteCurrentPage(drawingManager: CanvasDrawingManager) {
        guard pdfDocument.pageCount > 1 else { return }
        let removeIndex = currentPageIndex
        pdfDocument.removePage(at: removeIndex)
        drawingManager.shiftDrawingsForDelete(at: removeIndex)
        // Remove the deleted index and shift down indices above it
        addedPageIndices.removeAll { $0 == removeIndex }
        addedPageIndices = addedPageIndices.map { $0 > removeIndex ? $0 - 1 : $0 }
        if currentPageIndex >= pdfDocument.pageCount {
            currentPageIndex = pdfDocument.pageCount - 1
        }
        pageVersion += 1
    }

    // MARK: - Persistence

    func saveCanvasState() {
        let drawingData: [String: Data] = drawingManager.drawings.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value.dataRepresentation()
        }

        print("[CanvasVM] Saving: \(drawingData.count) drawings, \(drawingData.values.map(\.count).reduce(0,+)) bytes total")

        // Build tutor progress snapshot
        var tutorState: [String: TutorStepState] = savedTutorProgress ?? [:]
        if tutorModeOn, let label = activeQuestionLabel {
            tutorState[label] = TutorStepState(
                currentStepIndex: currentTutorStepIndex,
                stepEvaluations: [StepEvaluation(
                    progress: tutorEvalService.stepProgress,
                    status: tutorEvalService.status,
                    mistakeExplanation: tutorEvalService.mistakeExplanation
                )],
                lastTranscription: handwritingService.latexResult
            )
        }

        let state = CanvasDocumentData(
            documentId: document.id,
            originalPageCount: originalPageCount,
            addedPageIndices: addedPageIndices,
            overlaySettings: overlaySettings,
            currentPageIndex: currentPageIndex,
            drawingDataByPage: drawingData,
            tutorProgress: tutorState.isEmpty ? nil : tutorState
        )

        Task.detached {
            do {
                try CanvasStorageService.save(state)
                print("[CanvasVM] Save OK")
            } catch {
                print("[CanvasVM] Save failed: \(error)")
            }
        }
    }

    private func createBlankPage() -> PDFPage {
        let size: CGSize
        if let firstPage = pdfDocument.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            size = CGSize(width: bounds.width, height: bounds.height)
        } else {
            size = CGSize(width: 612, height: 792)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        guard let cgImage = image.cgImage else {
            return PDFPage()
        }

        let page = PDFPage(image: UIImage(cgImage: cgImage))!
        page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        return page
    }

    func addColor(_ color: UIColor) {
        switch selectedTool {
        case .highlighter:
            customHighlighterColors.append(color)
            highlighterColor = color
        case .shapes:
            customShapesColors.append(color)
            shapesColor = color
        default:
            customColors.append(color)
            penColor = color
        }
        showAddColor = false
    }

    var hasActiveOverlay: Bool {
        overlaySettings.type != .none
    }
}
