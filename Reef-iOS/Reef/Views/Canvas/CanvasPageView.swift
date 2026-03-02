import SwiftUI
import PDFKit
import PencilKit

struct CanvasPageView: UIViewRepresentable {
    let pdfPage: PDFPage
    let fingerDrawing: Bool
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.configure(pdfPage: pdfPage, drawing: drawing, fingerDrawing: fingerDrawing)
        container.canvasView.delegate = context.coordinator
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.canvasView.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly

        // Only update drawing if it changed externally (page switch)
        if uiView.canvasView.drawing != drawing {
            uiView.canvasView.drawing = drawing
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

// MARK: - Container UIView

final class CanvasContainerView: UIView {
    let canvasView = PKCanvasView()
    private let pdfImageView = UIImageView()
    private let toolPicker = PKToolPicker()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 5.0
        canvasView.bouncesZoom = true

        pdfImageView.contentMode = .topLeft

        addSubview(canvasView)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    func configure(pdfPage: PDFPage, drawing: PKDrawing, fingerDrawing: Bool) {
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0

        // Render PDF page to image
        let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: pageRect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
        }

        pdfImageView.image = image
        pdfImageView.frame = CGRect(origin: .zero, size: pageRect.size)

        // Set canvas content size to match PDF page
        canvasView.contentSize = pageRect.size
        canvasView.drawing = drawing
        canvasView.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly

        // Insert PDF image behind drawing content
        // PKCanvasView's first subview is the content view
        pdfImageView.removeFromSuperview()
        canvasView.insertSubview(pdfImageView, at: 0)

        // Show tool picker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }

    func updatePDFPage(_ pdfPage: PDFPage, drawing: PKDrawing) {
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0

        let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: pageRect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
        }

        pdfImageView.image = image
        pdfImageView.frame = CGRect(origin: .zero, size: pageRect.size)
        canvasView.contentSize = pageRect.size
        canvasView.drawing = drawing
        canvasView.zoomScale = 1.0
    }
}
