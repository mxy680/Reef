//
//  CanvasPageView.swift
//  Reef
//
//  Custom drawing canvas — Core Graphics based, no PencilKit
//

import SwiftUI
import PDFKit

struct CanvasPageView: UIViewRepresentable {
    let pdfPage: PDFPage
    let fingerDrawing: Bool
    let tool: DrawingTool
    let strokeColor: StrokeColor
    let lineWidth: CGFloat
    let strokes: [Stroke]
    let onDrawingAction: (DrawingAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CanvasScrollView {
        let scrollView = CanvasScrollView()
        scrollView.configure(
            pdfPage: pdfPage,
            strokes: strokes,
            coordinator: context.coordinator
        )
        return scrollView
    }

    func updateUIView(_ uiView: CanvasScrollView, context: Context) {
        context.coordinator.parent = self
        uiView.drawingView.currentTool = tool
        uiView.drawingView.currentColor = strokeColor
        uiView.drawingView.currentLineWidth = lineWidth
        uiView.drawingView.allowFingerDrawing = fingerDrawing
        uiView.drawingView.updateCommittedStrokes(strokes)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: CanvasPageView

        init(parent: CanvasPageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? CanvasScrollView)?.contentContainer
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? CanvasScrollView else { return }
            let container = canvas.contentContainer
            let sw = scrollView.bounds.width
            let sh = scrollView.bounds.height
            let cw = container.frame.width
            let ch = container.frame.height
            let offsetX = max((sw - cw) / 2, 0)
            let offsetY = max((sh - ch) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: offsetY, left: offsetX,
                bottom: offsetY, right: offsetX
            )
        }

        func handleAction(_ action: DrawingAction) {
            parent.onDrawingAction(action)
        }
    }
}

// MARK: - Scroll View Container

final class CanvasScrollView: UIScrollView {
    let contentContainer = UIView()
    let pdfImageView = UIImageView()
    let drawingView = DrawingCanvasView()

    private var hasSetInitialZoom = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delaysContentTouches = false

        addSubview(contentContainer)
        contentContainer.addSubview(pdfImageView)
        contentContainer.addSubview(drawingView)

        pdfImageView.contentMode = .scaleToFill
        drawingView.backgroundColor = .clear
        drawingView.isOpaque = false
        drawingView.parentScrollView = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(
        pdfPage: PDFPage,
        strokes: [Stroke],
        coordinator: CanvasPageView.Coordinator
    ) {
        delegate = coordinator
        hasSetInitialZoom = false

        drawingView.onDrawingAction = { [weak coordinator] action in
            coordinator?.handleAction(action)
        }

        let pageRect = pdfPage.bounds(for: .mediaBox)

        // Render PDF page to a 2x image for retina clarity
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageRect.size))
            ctx.cgContext.translateBy(x: 0, y: pageRect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
        }

        pdfImageView.image = image
        let contentFrame = CGRect(origin: .zero, size: pageRect.size)
        contentContainer.frame = contentFrame
        pdfImageView.frame = contentFrame
        drawingView.frame = contentFrame
        drawingView.updateCommittedStrokes(strokes)
        contentSize = pageRect.size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetInitialZoom,
              contentContainer.frame.width > 0,
              bounds.width > 0 else { return }

        let widthScale = bounds.width / contentContainer.frame.width
        minimumZoomScale = widthScale
        zoomScale = widthScale
        hasSetInitialZoom = true
    }
}

// MARK: - Drawing Canvas View

final class DrawingCanvasView: UIView {

    // Public state — set from UIViewRepresentable
    var currentTool: DrawingTool = .pen
    var currentColor: StrokeColor = .black
    var currentLineWidth: CGFloat = 3.0
    var allowFingerDrawing = false
    weak var parentScrollView: UIScrollView?
    var onDrawingAction: ((DrawingAction) -> Void)?

    // Internal drawing state
    private var committedStrokes: [Stroke] = []
    private var activeStroke: Stroke?
    private var isActivelyDrawing = false

    // Eraser local state — modified during drag, synced on end
    private var localStrokes: [Stroke] = []
    private var eraserDidModify = false

    // Bitmap cache for committed strokes
    private var strokesBitmap: UIImage?
    private var bitmapNeedsUpdate = true

    // Eraser cursor
    private lazy var eraserCursorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.systemGray.withAlphaComponent(0.15).cgColor
        layer.strokeColor = UIColor.systemGray.withAlphaComponent(0.6).cgColor
        layer.lineWidth = 1.5
        layer.isHidden = true
        self.layer.addSublayer(layer)
        return layer
    }()

    // MARK: - Stroke Updates

    func updateCommittedStrokes(_ strokes: [Stroke]) {
        guard !isActivelyDrawing else { return }
        committedStrokes = strokes
        localStrokes = strokes
        bitmapNeedsUpdate = true
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Draw cached bitmap of committed strokes
        if bitmapNeedsUpdate {
            rebuildBitmap()
        }
        strokesBitmap?.draw(in: bounds)

        // Draw active stroke on top
        if let stroke = activeStroke {
            Self.renderStroke(stroke, in: ctx)
        }
    }

    private func rebuildBitmap() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        strokesBitmap = renderer.image { rendererCtx in
            let strokesToRender = isActivelyDrawing && currentTool == .eraser
                ? localStrokes
                : committedStrokes
            for stroke in strokesToRender {
                Self.renderStroke(stroke, in: rendererCtx.cgContext)
            }
        }
        bitmapNeedsUpdate = false
    }

    static func renderStroke(_ stroke: Stroke, in ctx: CGContext) {
        guard !stroke.points.isEmpty else { return }

        // Single-point tap → draw a dot
        if stroke.points.count == 1 {
            let point = stroke.points[0]
            ctx.saveGState()
            if stroke.tool == .highlighter { ctx.setAlpha(0.3) }
            ctx.setFillColor(stroke.color.uiColor.cgColor)
            let r = stroke.lineWidth / 2
            ctx.fillEllipse(in: CGRect(
                x: point.x - r, y: point.y - r,
                width: stroke.lineWidth, height: stroke.lineWidth
            ))
            ctx.restoreGState()
            return
        }

        ctx.saveGState()

        if stroke.tool == .highlighter {
            ctx.setAlpha(0.3)
            ctx.setBlendMode(.normal)
        }

        ctx.setStrokeColor(stroke.color.uiColor.cgColor)
        ctx.setLineWidth(stroke.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let path = CGMutablePath()
        path.move(to: stroke.points[0].location)

        // Quadratic bezier smoothing between midpoints
        for i in 1..<stroke.points.count {
            let prev = stroke.points[i - 1].location
            let curr = stroke.points[i].location
            let mid = CGPoint(
                x: (prev.x + curr.x) / 2,
                y: (prev.y + curr.y) / 2
            )
            path.addQuadCurve(to: mid, control: prev)
        }
        path.addLine(to: stroke.points.last!.location)

        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Touch Handling

    private func shouldDraw(_ touch: UITouch) -> Bool {
        touch.type == .pencil || allowFingerDrawing
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, shouldDraw(touch) else {
            super.touchesBegan(touches, with: event)
            return
        }

        isActivelyDrawing = true
        parentScrollView?.isScrollEnabled = false
        parentScrollView?.pinchGestureRecognizer?.isEnabled = false

        let point = touch.location(in: self)
        let force: CGFloat = touch.type == .pencil ? max(touch.force, 0.1) : 1.0

        if currentTool == .eraser {
            localStrokes = committedStrokes
            eraserDidModify = false
            eraseAtPoint(point)
            showEraserCursor(at: point)
        } else {
            activeStroke = Stroke(
                tool: currentTool,
                color: currentColor,
                lineWidth: currentLineWidth,
                points: [StrokePoint(location: point, force: force)]
            )
        }

        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, shouldDraw(touch), isActivelyDrawing else {
            super.touchesMoved(touches, with: event)
            return
        }

        if currentTool == .eraser {
            // Use coalesced touches for thorough erasing across fast movements
            let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
            for t in coalesced {
                eraseAtPoint(t.location(in: self))
            }
            moveEraserCursor(to: touch.location(in: self))
        } else {
            // Use coalesced touches for smooth strokes
            let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
            for t in coalesced {
                let pt = t.location(in: self)
                let f: CGFloat = t.type == .pencil ? max(t.force, 0.1) : 1.0
                activeStroke?.points.append(StrokePoint(location: pt, force: f))
            }
        }

        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, shouldDraw(touch), isActivelyDrawing else {
            super.touchesEnded(touches, with: event)
            return
        }
        finishDrawing()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isActivelyDrawing = false
        activeStroke = nil
        parentScrollView?.isScrollEnabled = true
        parentScrollView?.pinchGestureRecognizer?.isEnabled = true
        hideEraserCursor()
        setNeedsDisplay()
        super.touchesCancelled(touches, with: event)
    }

    private func finishDrawing() {
        isActivelyDrawing = false
        parentScrollView?.isScrollEnabled = true
        parentScrollView?.pinchGestureRecognizer?.isEnabled = true

        if currentTool == .eraser {
            if eraserDidModify {
                committedStrokes = localStrokes
                bitmapNeedsUpdate = true
                onDrawingAction?(.eraseStrokes(remaining: localStrokes))
            }
            hideEraserCursor()
        } else if let stroke = activeStroke, stroke.points.count >= 1 {
            committedStrokes.append(stroke)
            localStrokes = committedStrokes
            bitmapNeedsUpdate = true
            onDrawingAction?(.addStroke(stroke))
        }

        activeStroke = nil
        setNeedsDisplay()
    }

    // MARK: - Erasing

    private func eraseAtPoint(_ point: CGPoint) {
        let eraserRadius = currentLineWidth / 2
        var remaining: [Stroke] = []
        var didErase = false

        for stroke in localStrokes {
            var intersects = false
            for sp in stroke.points {
                let dx = sp.x - point.x
                let dy = sp.y - point.y
                let distSq = dx * dx + dy * dy
                let threshold = eraserRadius + stroke.lineWidth / 2
                if distSq < threshold * threshold {
                    intersects = true
                    break
                }
            }
            if intersects {
                didErase = true
            } else {
                remaining.append(stroke)
            }
        }

        if didErase {
            localStrokes = remaining
            eraserDidModify = true
            bitmapNeedsUpdate = true
        }
    }

    // MARK: - Eraser Cursor

    private func showEraserCursor(at point: CGPoint) {
        let size = currentLineWidth
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        eraserCursorLayer.path = UIBezierPath(ovalIn: rect).cgPath
        eraserCursorLayer.bounds = rect
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eraserCursorLayer.position = point
        eraserCursorLayer.isHidden = false
        CATransaction.commit()
    }

    private func moveEraserCursor(to point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eraserCursorLayer.position = point
        CATransaction.commit()
    }

    private func hideEraserCursor() {
        eraserCursorLayer.isHidden = true
    }
}
