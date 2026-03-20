import SwiftUI
import PDFKit
import PencilKit

// MARK: - Canvas Page View (UIViewRepresentable bridge)

struct CanvasPageView: UIViewRepresentable {
    var pdfDocument: PDFDocument
    let drawingManager: CanvasDrawingManager
    let currentTool: PKTool
    var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly
    var darkMode: Bool = false
    var overlayType: CanvasOverlayType = .none
    var overlaySpacing: CGFloat = 20
    var overlayOpacity: CGFloat = 0.35
    var pageVersion: Int = 0
    var scrollToPageIndex: Int? = nil
    var onCanvasTouchBegan: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.drawingManager = drawingManager
        container.currentTool = currentTool
        container.drawingPolicy = drawingPolicy
        container.onCanvasTouchBegan = onCanvasTouchBegan
        container.onZoomChanged = onZoomChanged
        container.configure(pdfDocument: pdfDocument, pageVersion: pageVersion)
        container.applyDarkMode(darkMode)
        container.updateOverlay(type: overlayType, spacing: overlaySpacing, opacity: overlayOpacity)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.currentTool = currentTool
        uiView.drawingPolicy = drawingPolicy
        uiView.onCanvasTouchBegan = onCanvasTouchBegan
        uiView.onZoomChanged = onZoomChanged

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
