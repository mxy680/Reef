import SwiftUI
import PencilKit
import PDFKit
import UIKit
import AVFoundation
@preconcurrency import Supabase

// MARK: - Canvas ViewModel

@Observable
@MainActor
final class CanvasViewModel {
    let document: Document

    // MARK: - PDF

    var pdfDocument: PDFDocument
    var isLoadingPDF: Bool = true  // Set true synchronously — loadPDF task clears it
    var pdfError: String?
    private var loadPDFTask: Task<Void, Never>?

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

    /// When true on the simulator, touch input pans instead of drawing.
    #if targetEnvironment(simulator)
    var simulatorPanMode = false
    #endif

    var activeDrawingPolicy: PKCanvasViewDrawingPolicy {
        // The iOS Simulator does not support Apple Pencil input. Using `.anyInput` allows
        // touch/mouse drawing during development so the canvas is testable without real hardware.
        // On device, only Pencil input is accepted (unless the hand-draw tool is active).
        #if targetEnvironment(simulator)
        return simulatorPanMode ? .pencilOnly : .anyInput
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
    var activeQuestionLabel: String?
    /// Stroke bounds drawn with the shape tool — excluded from sync.
    private var shapeStrokeBounds: Set<CGRect> = []
    var showCalculator: Bool = false
    let calculatorViewModel = CalculatorViewModel()
    let syncService = CanvasSyncService()
    private var strokeUpsertWork: DispatchWorkItem?
    /// True while applying remote strokes from Realtime — suppresses onDrawingChanged
    var isApplyingRemoteStrokes: Bool = false
    var showClearConfirmation: Bool = false
    var showResetQuestionConfirmation: Bool = false
    var showBugReport: Bool = false
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

    // MARK: - Question Region Helpers

    /// Derives question number from activeQuestionLabel.
    var activeQuestionNumber: Int {
        guard let label = activeQuestionLabel, label.hasPrefix("Q") else { return 1 }
        var numStr = ""
        for ch in label.dropFirst() {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        return Int(numStr) ?? 1
    }

    /// Whether this document has been reconstructed (has answer keys available)
    var isReconstructed: Bool {
        document.problemCount != nil && (document.problemCount ?? 0) > 0
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

        // Wire Realtime stroke sync — REPLACE canvas with external strokes (from simulator)
        syncService.onStrokesUpdated = { [weak self] row in
            guard let self else { return }
            let page = row.pageIndex
            guard let container = self.containerView, page < container.canvasViews.count else { return }

            // Build PKDrawing from stroke data (1:1 coordinates — no scale)
            let ink = PKInk(.pen, color: .black)
            var drawing = PKDrawing()

            for strokeData in row.strokes {
                guard !strokeData.x.isEmpty, strokeData.x.count == strokeData.y.count else { continue }
                let points = zip(strokeData.x, strokeData.y).enumerated().map { idx, pair in
                    PKStrokePoint(
                        location: CGPoint(x: pair.0, y: pair.1),
                        timeOffset: TimeInterval(idx) * 0.01,
                        size: CGSize(width: 3, height: 3),
                        opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 4
                    )
                }
                let path = PKStrokePath(controlPoints: points, creationDate: Date())
                drawing.strokes.append(PKStroke(ink: ink, path: path))
            }

            // REPLACE the entire page drawing (not append)
            self.isApplyingRemoteStrokes = true
            self.drawingManager.setDrawing(drawing, for: page)
            container.canvasViews[page].drawing = drawing
            self.isApplyingRemoteStrokes = false
        }

        // Wire Realtime stroke delete — clear canvas
        syncService.onStrokesDeleted = { [weak self] in
            guard let self, let container = self.containerView else { return }
            print("[Realtime] Clearing all canvas pages")
            self.isApplyingRemoteStrokes = true
            for i in 0..<container.canvasViews.count {
                self.drawingManager.setDrawing(PKDrawing(), for: i)
                container.canvasViews[i].drawing = PKDrawing()
            }
            self.isApplyingRemoteStrokes = false
        }

        loadPDFTask = Task { await loadPDF() }
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

            // If document is still processing, poll until completed (up to 5 min)
            var isReconstructedDoc = document.status == .completed && (document.problemCount ?? 0) > 0
            if document.status == .processing {
                var attempts = 0
                while attempts < 60 && !Task.isCancelled {
                    attempts += 1
                    try? await Task.sleep(for: .seconds(5))
                    if let updated = try? await repo.getDocument(document.id),
                       updated.status != .processing {
                        isReconstructedDoc = updated.status == .completed && (updated.problemCount ?? 0) > 0
                        break
                    }
                }
            }

            // Only fetch output.pdf if reconstruction completed successfully
            let signedURL = try await repo.getDownloadURL(document.id, preferOutput: isReconstructedDoc)
            let (data, _) = try await Self.pdfSession.data(from: signedURL)
            guard let pdf = PDFDocument(data: data) else {
                pdfError = "Unable to open PDF"
                isLoadingPDF = false
                return
            }
            pdfDocument = pdf
            originalPageCount = pdf.pageCount

            // Capture active question label before clearing savedState
            let restoredQuestionLabel = savedState?.activeQuestionLabel

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
            pageVersion += 1

            // Start stroke sync polling
            syncService.startPolling(documentId: document.id)

            // Restore last active question
            if activeQuestionLabel == nil {
                activeQuestionLabel = restoredQuestionLabel ?? "Q1a"
            }
        } catch {
            pdfError = "Failed to download document"
        }
        isLoadingPDF = false
    }

    // MARK: - Drawing Changes

    func onDrawingChanged(forPage pageOverride: Int? = nil) {
        guard !isApplyingRemoteStrokes else { return }

        let page = pageOverride ?? currentPageIndex

        // ~100ms debounce to detect pen lift (fires once after last point)
        strokeUpsertWork?.cancel()
        let upsertWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let drawing = self.drawingWithoutShapes(for: page)
            let strokes = CanvasSyncService.extractStrokePayloads(from: drawing)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.syncService.writeStrokes(
                    documentId: self.document.id,
                    questionLabel: self.activeQuestionLabel ?? "Q1a",
                    pageIndex: page,
                    strokes: strokes
                )
            }
        }
        strokeUpsertWork = upsertWork
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: upsertWork)
    }

    func cancelAllTasks() {
        loadPDFTask?.cancel()
        strokeUpsertWork?.cancel()
        syncService.stopPolling()
    }

    // MARK: - Question Region Detection

    func updateActiveQuestion(pageIndex: Int, yPosition: Double) {
        currentPageIndex = pageIndex

        let originalPage = originalPageIndex(for: pageIndex)
        let newLabel = QuestionRegionTracker.activeLabel(
            forPage: originalPage,
            yPosition: yPosition,
            questionRegions: document.questionRegions,
            questionPages: document.questionPages
        )

        if newLabel != activeQuestionLabel {
            activeQuestionLabel = newLabel
        }
    }

    /// Returns only the active SUBquestion's regions for stroke filtering.
    func activeSubquestionRegions() -> [PartRegion]? {
        guard let label = activeQuestionLabel,
              let qPages = document.questionPages,
              let qRegions = document.questionRegions else { return nil }

        guard label.hasPrefix("Q"), label.count >= 3 else { return nil }
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
        guard let qNum = Int(numStr), qNum >= 1 else { return nil }
        let qi = qNum - 1

        guard qi < qPages.count, qi < qRegions.count,
              let data = qRegions[qi] else { return nil }

        let targetLabel = partLabel.isEmpty ? nil : partLabel
        return data.regions.filter { $0.label == targetLabel }
    }

    /// Map current page index back to original index, accounting for added blank pages.
    private func originalPageIndex(for currentIndex: Int) -> Int {
        let addedBefore = addedPageIndices.filter { $0 <= currentIndex }.count
        return currentIndex - addedBefore
    }

    // MARK: - Question Navigation

    /// Ordered list of all question labels in the document (e.g. ["Q1a", "Q1b", "Q2a", ...]).
    var allQuestionLabels: [String] {
        guard let qPages = document.questionPages,
              let qRegions = document.questionRegions else { return [] }

        var labels: [String] = []
        for (qi, _) in qPages.enumerated() {
            let qNum = qi + 1
            if qi < qRegions.count, let data = qRegions[qi] {
                var seen = Set<String>()
                for region in data.regions {
                    let partLabel = region.label ?? "a"
                    let full = "Q\(qNum)\(partLabel)"
                    if seen.insert(full).inserted {
                        labels.append(full)
                    }
                }
            } else {
                labels.append("Q\(qNum)a")
            }
        }
        return labels
    }

    var canGoToPreviousQuestion: Bool {
        guard let label = activeQuestionLabel else { return false }
        let labels = allQuestionLabels
        guard let idx = labels.firstIndex(of: label) else { return false }
        return idx > 0
    }

    var canSkipToNextQuestion: Bool {
        guard let label = activeQuestionLabel else { return !allQuestionLabels.isEmpty }
        let labels = allQuestionLabels
        guard let idx = labels.firstIndex(of: label) else { return false }
        return idx < labels.count - 1
    }

    /// Skip to the next question/subquestion. Returns the page index to scroll to, or nil.
    func skipToNextQuestion() -> Int? {
        let labels = allQuestionLabels
        let currentLabel = activeQuestionLabel ?? ""
        let currentIdx = labels.firstIndex(of: currentLabel) ?? -1
        let nextIdx = currentIdx + 1
        guard nextIdx < labels.count else { return nil }

        let nextLabel = labels[nextIdx]

        guard nextLabel.hasPrefix("Q"), nextLabel.count >= 2 else { return nil }
        let numAndLabel = nextLabel.dropFirst()
        var numStr = ""
        for ch in numAndLabel {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        guard let qNum = Int(numStr), qNum >= 1,
              let qPages = document.questionPages,
              qNum - 1 < qPages.count else { return nil }

        let pageRange = qPages[qNum - 1]
        guard pageRange.count >= 2 else { return nil }

        activeQuestionLabel = nextLabel
        strokeUpsertWork?.cancel()

        return pageRange[0]
    }

    func goToPreviousQuestion() {
        let labels = allQuestionLabels
        let currentLabel = activeQuestionLabel ?? ""
        guard let currentIdx = labels.firstIndex(of: currentLabel), currentIdx > 0 else { return }

        let prevLabel = labels[currentIdx - 1]
        activeQuestionLabel = prevLabel
        strokeUpsertWork?.cancel()
    }

    // MARK: - Actions

    func dismissAllPopovers() {
        showToolSettings = false
        showEraserSettings = false
        showPageSettings = false
        showPageMenu = false
        showPageControls = false
    }

    func exportDocument() {
        guard !isExporting, let container = containerView else { return }
        isExporting = true

        let wasDarkMode = isDarkMode
        if wasDarkMode {
            isDarkMode = false
            container.applyDarkMode(false)
        }

        let data = CanvasExportService.exportFromContainer(container)

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

    /// Reset all work for the current question: erase strokes on its pages and clear DB rows.
    func resetCurrentQuestion() {
        guard let container = containerView else { return }

        let label = activeQuestionLabel ?? "Q1a"
        guard let qPages = document.questionPages else { return }

        guard label.hasPrefix("Q"), label.count >= 2 else { return }
        var numStr = ""
        for ch in label.dropFirst() {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        guard let qNum = Int(numStr), qNum >= 1, qNum - 1 < qPages.count else { return }

        let pageRange = qPages[qNum - 1]
        guard pageRange.count >= 2 else { return }

        let prefix = "Q\(qNum)"
        let subLabels = allQuestionLabels.filter { $0.hasPrefix(prefix) }

        let savedCallback = drawingManager.onDrawingChanged
        drawingManager.onDrawingChanged = nil
        for origPageIdx in pageRange[0]...pageRange[1] {
            let addedBefore = addedPageIndices.filter { $0 <= origPageIdx }.count
            let actualPageIdx = origPageIdx + addedBefore
            if actualPageIdx < container.canvasViews.count {
                drawingManager.setDrawing(PKDrawing(), for: actualPageIdx)
                container.canvasViews[actualPageIdx].drawing = PKDrawing()
            }
        }
        drawingManager.onDrawingChanged = savedCallback
        drawingManager.onDrawingChanged?()

        strokeUpsertWork?.cancel()
        clearShapeStrokes()
        saveCanvasState()

        Task {
            await syncService.clearStrokesForQuestion(documentId: document.id, questionLabels: subLabels)
        }
    }

    // MARK: - Shape Stroke Tracking

    func markShapeStrokes(in drawing: PKDrawing) {
        for stroke in drawing.strokes {
            shapeStrokeBounds.insert(stroke.renderBounds)
        }
    }

    func drawingWithoutShapes(for pageIndex: Int) -> PKDrawing {
        let drawing = drawingManager.drawing(for: pageIndex)
        guard !shapeStrokeBounds.isEmpty else { return drawing }

        let filtered = drawing.strokes.filter { stroke in
            !shapeStrokeBounds.contains(stroke.renderBounds)
        }
        var newDrawing = PKDrawing()
        for stroke in filtered {
            newDrawing.strokes.append(stroke)
        }
        return newDrawing
    }

    func clearShapeStrokes() {
        shapeStrokeBounds.removeAll()
    }

    // MARK: - Page Mutations

    func addBlankPageAtEnd(drawingManager: CanvasDrawingManager) {
        let insertIndex = pdfDocument.pageCount
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        addedPageIndices.append(insertIndex)
        containerView?.skipDrawingSaveOnRebuild = true
        pageVersion += 1
    }

    func addBlankPageAfterCurrent(drawingManager: CanvasDrawingManager) {
        let insertIndex = currentPageIndex + 1
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        addedPageIndices = addedPageIndices.map { $0 >= insertIndex ? $0 + 1 : $0 }
        addedPageIndices.append(insertIndex)
        containerView?.skipDrawingSaveOnRebuild = true
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

        clearShapeStrokes()
        saveCanvasState()
    }

    func deleteCurrentPage(drawingManager: CanvasDrawingManager) {
        guard pdfDocument.pageCount > 1 else { return }
        let removeIndex = currentPageIndex
        pdfDocument.removePage(at: removeIndex)
        drawingManager.shiftDrawingsForDelete(at: removeIndex)
        addedPageIndices.removeAll { $0 == removeIndex }
        addedPageIndices = addedPageIndices.map { $0 > removeIndex ? $0 - 1 : $0 }
        if currentPageIndex >= pdfDocument.pageCount {
            currentPageIndex = pdfDocument.pageCount - 1
        }
        containerView?.skipDrawingSaveOnRebuild = true
        pageVersion += 1
    }

    // MARK: - Persistence

    func saveCanvasState() {
        let drawingData: [String: Data] = drawingManager.drawings.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value.dataRepresentation()
        }

        print("[CanvasVM] Saving: \(drawingData.count) drawings, \(drawingData.values.map(\.count).reduce(0,+)) bytes total")

        let state = CanvasDocumentData(
            documentId: document.id,
            originalPageCount: originalPageCount,
            addedPageIndices: addedPageIndices,
            overlaySettings: overlaySettings,
            currentPageIndex: currentPageIndex,
            drawingDataByPage: drawingData,
            tutorProgress: nil,
            activeQuestionLabel: activeQuestionLabel
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

        guard let page = PDFPage(image: UIImage(cgImage: cgImage)) else {
            return PDFPage()
        }
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
