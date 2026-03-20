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
    var isMicOn: Bool = false
    var showCalculator: Bool = false
    let calculatorViewModel = CalculatorViewModel()

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
        return Double(currentTutorStepIndex) / Double(tutorStepCount)
    }

    func loadAnswerKeys() async {
        guard isReconstructed else { return }
        isLoadingAnswerKeys = true
        let repo = SupabaseAnswerKeyRepository()
        let result = await repo.fetchAnswerKeys(documentId: document.id)
        answerKeys = result.answers
        isLoadingAnswerKeys = false
    }

    // MARK: - Toolbar Layout

    var toolbarRowMinX: CGFloat = 0
    var toolbarRowWidth: CGFloat = 0

    // MARK: - Init

    init(document: Document) {
        self.document = document
        self.pdfDocument = MockCanvasData.blankPDF()
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
            pageVersion += 1
        } catch {
            pdfError = "Failed to download document"
        }
        isLoadingPDF = false
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
        showHintPopover = false
        showRevealPopover = false
    }

    func resetTutorSteps() {
        currentTutorStepIndex = 0
        showHintPopover = false
        showRevealPopover = false
    }

    // MARK: - Page Mutations

    func addBlankPageAtEnd(drawingManager: CanvasDrawingManager) {
        let insertIndex = pdfDocument.pageCount
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        pageVersion += 1
    }

    func addBlankPageAfterCurrent(drawingManager: CanvasDrawingManager) {
        let insertIndex = currentPageIndex + 1
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        pageVersion += 1
    }

    func deleteCurrentPage(drawingManager: CanvasDrawingManager) {
        guard pdfDocument.pageCount > 1 else { return }
        let removeIndex = currentPageIndex
        pdfDocument.removePage(at: removeIndex)
        drawingManager.shiftDrawingsForDelete(at: removeIndex)
        if currentPageIndex >= pdfDocument.pageCount {
            currentPageIndex = pdfDocument.pageCount - 1
        }
        pageVersion += 1
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
