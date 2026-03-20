import SwiftUI
import PDFKit
import PencilKit

// MARK: - Canvas Page View (UIViewRepresentable bridge)

struct CanvasPageView: UIViewRepresentable {
    var pdfDocument: PDFDocument
    let drawingManager: CanvasDrawingManager
    let currentTool: PKTool
    var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly
    var selectedToolType: CanvasToolType = .pen
    var darkMode: Bool = false
    var overlayType: CanvasOverlayType = .none
    var overlaySpacing: CGFloat = 20
    var overlayOpacity: CGFloat = 0.35
    var pageVersion: Int = 0
    var scrollToPageIndex: Int? = nil
    var onCanvasTouchBegan: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    var onStrokePositionChanged: ((_ pageIndex: Int, _ yPosition: Double) -> Void)?
    var onContainerCreated: ((CanvasContainerView) -> Void)?

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.drawingManager = drawingManager
        container.currentTool = currentTool
        container.drawingPolicy = drawingPolicy
        container.selectedToolType = selectedToolType
        container.onCanvasTouchBegan = onCanvasTouchBegan
        container.onZoomChanged = onZoomChanged
        container.onStrokePositionChanged = onStrokePositionChanged
        container.configure(pdfDocument: pdfDocument, pageVersion: pageVersion)
        container.applyDarkMode(darkMode)
        container.updateOverlay(type: overlayType, spacing: overlaySpacing, opacity: overlayOpacity)
        onContainerCreated?(container)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.currentTool = currentTool
        uiView.drawingPolicy = drawingPolicy
        uiView.selectedToolType = selectedToolType
        uiView.onCanvasTouchBegan = onCanvasTouchBegan
        uiView.onZoomChanged = onZoomChanged
        uiView.onStrokePositionChanged = onStrokePositionChanged

        // Re-render pages when the PDF document or page structure changes
        if uiView.currentPageVersion != pageVersion {
            uiView.configure(pdfDocument: pdfDocument, pageVersion: pageVersion)
        }

        if let index = scrollToPageIndex {
            uiView.scrollToPage(index)
        }

        uiView.applyDarkMode(darkMode)
        uiView.updateOverlay(type: overlayType, spacing: overlaySpacing, opacity: overlayOpacity)
    }
}
