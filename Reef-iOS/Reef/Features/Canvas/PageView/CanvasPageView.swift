import SwiftUI
import PDFKit
import PencilKit

// MARK: - Canvas Page View (UIViewRepresentable bridge)

struct CanvasPageView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    let drawingManager: CanvasDrawingManager
    let currentTool: PKTool
    var darkMode: Bool = false
    var overlayType: CanvasOverlayType = .none
    var overlaySpacing: CGFloat = 20
    var overlayOpacity: CGFloat = 0.35
    var onCanvasTouchBegan: (() -> Void)?

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.drawingManager = drawingManager
        container.currentTool = currentTool
        container.onCanvasTouchBegan = onCanvasTouchBegan
        container.configure(pdfDocument: pdfDocument)
        container.applyDarkMode(darkMode)
        container.updateOverlay(type: overlayType, spacing: overlaySpacing, opacity: overlayOpacity)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.currentTool = currentTool
        uiView.onCanvasTouchBegan = onCanvasTouchBegan
        uiView.applyDarkMode(darkMode)
        uiView.updateOverlay(type: overlayType, spacing: overlaySpacing, opacity: overlayOpacity)
    }
}
