import SwiftUI
import PencilKit
import PDFKit

// MARK: - Canvas ViewModel

@Observable
@MainActor
final class CanvasViewModel {
    let document: Document

    // MARK: - PDF

    let pdfDocument: PDFDocument

    // MARK: - Tool State

    var selectedTool: CanvasToolType = .pen
    var penColor: UIColor = .black
    var penWidth: CGFloat = 2.0
    var eraserMode: PKEraserTool.EraserType = .vector
    var eraserWidth: CGFloat = 8.0
    var customColors: [UIColor] = []

    /// The active PKTool derived from current settings.
    var activePKTool: PKTool {
        selectedTool.pkTool(
            color: penColor,
            width: penWidth,
            eraserType: eraserMode,
            eraserWidth: eraserWidth
        )
    }

    // MARK: - Page State

    var currentPageIndex: Int = 0
    var zoomScale: CGFloat = 1.0
    var overlaySettings: CanvasOverlaySettings = CanvasOverlaySettings()

    var pageCount: Int {
        pdfDocument.pageCount
    }

    var zoomPercentage: Int {
        Int(zoomScale * 100)
    }

    // MARK: - UI State

    var showRuler: Bool = false
    var isDarkMode: Bool = false

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

    // MARK: - Tutor State

    var tutorModeOn: Bool = false
    var currentTutorStepIndex: Int = 0
    var showHintPopover: Bool = false
    var showRevealPopover: Bool = false
    var hintMidX: CGFloat = 0
    var revealMidX: CGFloat = 0

    var currentTutorStep: MockTutorStep? {
        let steps = MockCanvasData.tutorSteps
        guard currentTutorStepIndex < steps.count else { return nil }
        return steps[currentTutorStepIndex]
    }

    var tutorStepCount: Int { MockCanvasData.tutorSteps.count }

    var tutorProgress: Double {
        guard tutorStepCount > 0 else { return 0 }
        return Double(currentTutorStepIndex) / Double(tutorStepCount)
    }

    // MARK: - Toolbar Layout

    var toolbarRowMinX: CGFloat = 0
    var toolbarRowWidth: CGFloat = 0

    // MARK: - Init

    init(document: Document) {
        self.document = document
        self.pdfDocument = MockCanvasData.blankPDF()
    }

    // MARK: - Actions

    func dismissAllPopovers() {
        showToolSettings = false
        showEraserSettings = false
        showPageSettings = false
        showPageMenu = false
        showHintPopover = false
        showRevealPopover = false
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

    func addColor(_ color: UIColor) {
        customColors.append(color)
        showAddColor = false
    }

    var hasActiveOverlay: Bool {
        overlaySettings.type != .none
    }
}
