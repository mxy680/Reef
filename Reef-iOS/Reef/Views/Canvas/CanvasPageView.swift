//
//  CanvasPageView.swift
//  Reef
//
//  Renders all PDF pages vertically stacked in a zoomable scroll view
//  with a transparent PKCanvasView overlay per page for drawing
//

import SwiftUI
import PDFKit
import PencilKit

struct CanvasPageView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    let pageRange: ClosedRange<Int>?
    let drawingManager: DrawingManager
    let currentTool: PKTool
    var onVisiblePageChanged: ((Int) -> Void)?
    var onWritingPositionChanged: ((_ pageIndex: Int, _ yPDFPoints: Double) -> Void)?
    var darkMode: Bool = false
    var overlaySettings: PageOverlaySettings = PageOverlaySettings()
    var isEraserActive: Bool = false
    var eraserWidth: CGFloat = 8.0
    var onCanvasTouchBegan: (() -> Void)?

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.drawingManager = drawingManager
        container.pageIndexOffset = pageRange?.lowerBound ?? 0
        container.currentTool = currentTool
        container.onVisiblePageChanged = onVisiblePageChanged
        container.onWritingPositionChanged = onWritingPositionChanged
        container.onCanvasTouchBegan = onCanvasTouchBegan
        container.isEraserActive = isEraserActive
        container.eraserWidth = eraserWidth
        container.configure(pdfDocument: pdfDocument, pageRange: pageRange)
        container.applyDarkMode(darkMode)
        container.updateOverlay(overlaySettings)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.currentTool = currentTool
        uiView.onVisiblePageChanged = onVisiblePageChanged
        uiView.onWritingPositionChanged = onWritingPositionChanged
        uiView.onCanvasTouchBegan = onCanvasTouchBegan
        uiView.isEraserActive = isEraserActive
        uiView.eraserWidth = eraserWidth
        uiView.applyDarkMode(darkMode)
        uiView.updateOverlay(overlaySettings)
    }
}

// MARK: - Canvas Container View

final class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let pagesStackView = UIStackView()

    private var pageImageViews: [UIImageView] = []
    private var canvasViews: [PKCanvasView] = []
    private var pageContainerViews: [UIView] = []
    private var shadowViews: [UIView] = []
    private var pageOverlayViews: [PageOverlayView] = []
    private var separatorViews: [UIView] = []
    private var pageWrappers: [UIView] = []
    private var contentWidthConstraint: NSLayoutConstraint?
    private var isDarkMode = false
    private var currentOverlaySettings = PageOverlaySettings()

    /// Whether the eraser tool is currently active
    var isEraserActive = false {
        didSet {
            if !isEraserActive { eraserCursorView.isHidden = true }
        }
    }

    /// Eraser width in PDF points (canvas is 2x)
    var eraserWidth: CGFloat = 8.0 {
        didSet { updateEraserCursorSize() }
    }

    /// Faint circle showing eraser bounds during hover
    private let eraserCursorView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        view.layer.borderColor = UIColor.gray.cgColor
        view.layer.borderWidth = 1
        view.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
        return view
    }()

    /// Original rendered page images (light mode)
    private var originalImages: [UIImage] = []
    /// Color-inverted page images (dark mode) — lazily generated
    private var invertedImages: [UIImage]?

    /// Callback reporting the currently visible page index (PDF-absolute)
    var onVisiblePageChanged: ((Int) -> Void)?
    /// Callback reporting the writing position (page index + y in PDF points)
    var onWritingPositionChanged: ((_ pageIndex: Int, _ yPDFPoints: Double) -> Void)?
    /// Callback when pencil touches down on canvas (dismiss popovers)
    var onCanvasTouchBegan: (() -> Void)?
    private var startPageIndex: Int = 0
    private var lastReportedPage: Int = -1
    /// Track stroke counts per canvas to detect new strokes
    private var lastStrokeCounts: [Int: Int] = [:]

    /// Drawing state manager (owned by DocumentCanvasView, passed down)
    weak var drawingManager: DrawingManager?

    /// Offset for question-based page ranges (e.g., question 2 starts at page 4)
    var pageIndexOffset: Int = 0

    /// Current PencilKit tool — updated from toolbar
    var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 2) {
        didSet {
            canvasViews.forEach { $0.tool = currentTool }
        }
    }

    /// Separator height between pages (increased for 3D shadow clearance)
    private static let separatorHeight: CGFloat = 16

    /// Corner radius for the 3D page cards
    private static let pageCornerRadius: CGFloat = 12

    /// 3D shadow offset (matches ReefCard style)
    private static let shadowOffset: CGFloat = 6

    /// Border color for pages — gray500
    private static let pageBorderColor = UIColor(red: 140/255.0, green: 140/255.0, blue: 140/255.0, alpha: 1)

    /// Scroll area background — muted warm cream (#F8F0E6)
    private static let scrollBackground = UIColor(
        red: 0xF8 / 255.0, green: 0xF0 / 255.0, blue: 0xE6 / 255.0, alpha: 1
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // Scroll view — fills entire container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bouncesZoom = true
        scrollView.delegate = self
        scrollView.backgroundColor = Self.scrollBackground
        addSubview(scrollView)

        // Content view — zoomed as a unit
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

        // Vertical stack of page images
        pagesStackView.translatesAutoresizingMaskIntoConstraints = false
        pagesStackView.axis = .vertical
        pagesStackView.alignment = .center
        pagesStackView.distribution = .fill
        pagesStackView.spacing = 0
        contentView.addSubview(pagesStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            pagesStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pagesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pagesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pagesStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Eraser cursor (floats above canvas, follows hover)
        eraserCursorView.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        eraserCursorView.layer.cornerRadius = 8
        scrollView.addSubview(eraserCursorView)

        // Hover gesture for Apple Pencil
        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        scrollView.addGestureRecognizer(hoverGesture)
    }

    // MARK: - Configure

    func configure(pdfDocument: PDFDocument, pageRange: ClosedRange<Int>? = nil) {
        startPageIndex = pageRange?.lowerBound ?? 0
        Task { [weak self] in
            guard let self else { return }
            let images = await self.renderPDFPages(document: pdfDocument, pageRange: pageRange)

            await MainActor.run {
                self.setupPages(with: images)

                DispatchQueue.main.async {
                    self.centerAndFitDocument()
                }
            }
        }
    }

    // MARK: - Overlay

    func updateOverlay(_ settings: PageOverlaySettings) {
        guard settings != currentOverlaySettings else { return }
        currentOverlaySettings = settings

        for overlay in pageOverlayViews {
            overlay.overlayType = settings.type
            overlay.spacing = settings.spacing
            overlay.overlayOpacity = settings.opacity
            overlay.setNeedsDisplay()
        }
    }

    // MARK: - Render PDF

    private func renderPDFPages(document: PDFDocument, pageRange: ClosedRange<Int>? = nil) async -> [UIImage] {
        let scale: CGFloat = 2.0
        var images: [UIImage] = []

        let range = pageRange ?? 0...(document.pageCount - 1)
        for i in range {
            guard i < document.pageCount, let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            )
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
                ctx.cgContext.translateBy(x: 0, y: pageRect.height * scale)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }

        return images
    }

    // MARK: - Setup Pages

    private func setupPages(with images: [UIImage]) {
        // Clear existing
        for view in pageImageViews { view.removeFromSuperview() }
        for view in canvasViews { view.removeFromSuperview() }
        for view in pageOverlayViews { view.removeFromSuperview() }
        for view in separatorViews { view.removeFromSuperview() }
        pageImageViews.removeAll()
        canvasViews.removeAll()
        pageContainerViews.removeAll()
        shadowViews.removeAll()
        pageOverlayViews.removeAll()
        separatorViews.removeAll()
        pageWrappers.removeAll()
        lastReportedPage = -1
        pagesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        originalImages = images
        invertedImages = nil

        for (index, image) in images.enumerated() {
            // Wrapper holds both the shadow and the page (for 3D effect)
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.backgroundColor = .clear

            // 3D shadow — offset behind the page
            let shadowView = UIView()
            shadowView.translatesAutoresizingMaskIntoConstraints = false
            shadowView.backgroundColor = Self.pageBorderColor
            shadowView.layer.cornerRadius = Self.pageCornerRadius
            wrapper.addSubview(shadowView)
            shadowViews.append(shadowView)

            // Page container — white background with rounded corners and border
            let pageView = UIView()
            pageView.translatesAutoresizingMaskIntoConstraints = false
            pageView.backgroundColor = .white
            pageView.layer.cornerRadius = Self.pageCornerRadius
            pageView.layer.borderWidth = 2
            pageView.layer.borderColor = Self.pageBorderColor.cgColor
            pageView.clipsToBounds = true
            wrapper.addSubview(pageView)
            pageContainerViews.append(pageView)

            let imageView = UIImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            pageView.addSubview(imageView)
            pageImageViews.append(imageView)

            // PKCanvasView overlay — transparent, on top of PDF image
            let canvasView = TouchTrackingCanvasView()
            canvasView.onAnyTouchBegan = { [weak self] in
                self?.onCanvasTouchBegan?()
            }
            canvasView.onPencilTouch = { [weak self] location, phase in
                self?.handlePencilTouch(location: location, phase: phase, from: canvasView)
            }
            canvasView.translatesAutoresizingMaskIntoConstraints = false
            canvasView.backgroundColor = .clear
            canvasView.isOpaque = false
            canvasView.drawingPolicy = .pencilOnly
            canvasView.tool = currentTool
            canvasView.delegate = self
            canvasView.overrideUserInterfaceStyle = .light
            canvasView.isScrollEnabled = false

            // Load existing drawing
            let absolutePageIndex = pageIndexOffset + index
            if let manager = drawingManager {
                canvasView.drawing = manager.drawing(for: absolutePageIndex)
            }

            pageView.addSubview(canvasView)
            canvasViews.append(canvasView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),

                canvasView.topAnchor.constraint(equalTo: pageView.topAnchor),
                canvasView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                canvasView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                canvasView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])

            // Page overlay (grid / dots / lines)
            let overlayView = PageOverlayView()
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            overlayView.isUserInteractionEnabled = false
            overlayView.overlayType = currentOverlaySettings.type
            overlayView.spacing = currentOverlaySettings.spacing
            pageView.addSubview(overlayView)
            pageOverlayViews.append(overlayView)

            NSLayoutConstraint.activate([
                overlayView.topAnchor.constraint(equalTo: pageView.topAnchor),
                overlayView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                overlayView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])

            // Page sits at top-left of wrapper
            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                pageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                pageView.widthAnchor.constraint(equalToConstant: image.size.width),
                pageView.heightAnchor.constraint(equalToConstant: image.size.height),
            ])

            // Shadow is same size, offset right and down
            NSLayoutConstraint.activate([
                shadowView.topAnchor.constraint(equalTo: pageView.topAnchor, constant: Self.shadowOffset),
                shadowView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: Self.shadowOffset),
                shadowView.widthAnchor.constraint(equalTo: pageView.widthAnchor),
                shadowView.heightAnchor.constraint(equalTo: pageView.heightAnchor),
            ])

            // Wrapper size accounts for the shadow offset
            NSLayoutConstraint.activate([
                wrapper.widthAnchor.constraint(equalToConstant: image.size.width + Self.shadowOffset),
                wrapper.heightAnchor.constraint(equalToConstant: image.size.height + Self.shadowOffset),
            ])

            pagesStackView.addArrangedSubview(wrapper)
            pageWrappers.append(wrapper)

            // Separator between pages
            if index < images.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = .clear
                separatorViews.append(separator)
                pagesStackView.addArrangedSubview(separator)

                NSLayoutConstraint.activate([
                    separator.widthAnchor.constraint(equalTo: pagesStackView.widthAnchor),
                    separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight),
                ])
            }
        }

        // Content width matches widest page + shadow offset
        if let maxWidth = images.map({ $0.size.width }).max() {
            contentWidthConstraint?.isActive = false
            contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: maxWidth + Self.shadowOffset)
            contentWidthConstraint?.isActive = true
        }

        layoutIfNeeded()
    }

    // MARK: - Dark Mode

    func applyDarkMode(_ dark: Bool) {
        guard isDarkMode != dark else { return }
        isDarkMode = dark

        // Swap page images (invert colors for true dark mode reading)
        let targetImages: [UIImage]
        if dark {
            if invertedImages == nil {
                invertedImages = originalImages.map { Self.invertImage($0) }
            }
            targetImages = invertedImages!
        } else {
            targetImages = originalImages
        }

        UIView.transition(
            with: self,
            duration: 0.3,
            options: .transitionCrossDissolve
        ) { [self] in
            scrollView.backgroundColor = dark
                ? ReefColors.CanvasDark.scrollBackground
                : Self.scrollBackground

            for (i, pageView) in pageContainerViews.enumerated() {
                pageView.layer.borderColor = dark
                    ? ReefColors.CanvasDark.pageBorderUI.cgColor
                    : Self.pageBorderColor.cgColor

                if i < targetImages.count {
                    pageImageViews[i].image = targetImages[i]
                }
            }

            for shadowView in shadowViews {
                shadowView.backgroundColor = dark
                    ? UIColor.black.withAlphaComponent(0.5)
                    : Self.pageBorderColor
            }
        }
    }

    /// Invert an image's colors using CIColorInvert
    private static func invertImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIColorInvert") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { return image }

        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Layout

    private func centerAndFitDocument() {
        layoutIfNeeded()

        let viewportSize = scrollView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        guard let contentWidth = pageImageViews.first?.superview?.bounds.width,
              contentWidth > 0 else { return }

        // Zoom to fit width with horizontal padding
        let horizontalPadding: CGFloat = 40
        let availableWidth = viewportSize.width - horizontalPadding
        let zoomToFitWidth = availableWidth / contentWidth
        let targetZoom = min(max(zoomToFitWidth, scrollView.minimumZoomScale), scrollView.maximumZoomScale)

        scrollView.zoomScale = targetZoom

        setNeedsLayout()
        layoutIfNeeded()

        // Scroll to top
        scrollView.contentOffset = CGPoint(
            x: -scrollView.contentInset.left,
            y: -scrollView.contentInset.top - 20
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Center content when smaller than viewport
        let minTopPadding: CGFloat = 20
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, minTopPadding)
        scrollView.contentInset = UIEdgeInsets(
            top: offsetY, left: offsetX,
            bottom: offsetY, right: offsetX
        )
    }

    // MARK: - Eraser Cursor

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        guard isEraserActive else {
            eraserCursorView.isHidden = true
            return
        }

        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: scrollView)
            eraserCursorView.isHidden = false
            eraserCursorView.center = location
        case .ended, .cancelled:
            eraserCursorView.isHidden = true
        default:
            break
        }
    }

    private func handlePencilTouch(location: CGPoint, phase: UITouch.Phase, from view: UIView) {
        guard isEraserActive else {
            eraserCursorView.isHidden = true
            return
        }

        switch phase {
        case .began, .moved:
            let locationInScroll = view.convert(location, to: scrollView)
            eraserCursorView.isHidden = false
            eraserCursorView.center = locationInScroll
        case .ended, .cancelled:
            eraserCursorView.isHidden = true
        default:
            break
        }
    }

    private func updateEraserCursorSize() {
        // eraserWidth is in PDF points; canvas renders at 2x, then scrollView zoom applies
        let canvasSize = eraserWidth * 2.0 * scrollView.zoomScale
        eraserCursorView.bounds = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        eraserCursorView.layer.cornerRadius = canvasSize / 2
    }
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
        updateEraserCursorSize()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePage()
    }

    private func updateVisiblePage() {
        guard !pageWrappers.isEmpty else { return }

        let viewportCenterY = scrollView.bounds.height / 2
        var closestIndex = 0
        var closestDistance: CGFloat = .infinity

        for (index, wrapper) in pageWrappers.enumerated() {
            guard let superview = wrapper.superview else { continue }
            let centerInScrollView = superview.convert(wrapper.center, to: scrollView)
            let distance = abs(centerInScrollView.y - viewportCenterY)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }

        let actualPage = startPageIndex + closestIndex
        if actualPage != lastReportedPage {
            lastReportedPage = actualPage
            onVisiblePageChanged?(actualPage)
        }
    }
}

// MARK: - Page Overlay View

final class PageOverlayView: UIView {
    var overlayType: PageOverlayType = .none
    var spacing: CGFloat = 20
    var overlayOpacity: CGFloat = 0.35

    private var overlayColor: UIColor {
        UIColor(white: 0.72, alpha: overlayOpacity)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard overlayType != .none else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setStrokeColor(overlayColor.cgColor)
        ctx.setFillColor(overlayColor.cgColor)

        // Scale spacing by the 2x render factor
        let scaledSpacing = spacing * 2.0

        switch overlayType {
        case .none:
            break

        case .grid:
            ctx.setLineWidth(0.5)
            // Vertical lines
            var x: CGFloat = scaledSpacing
            while x < rect.width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: rect.height))
                x += scaledSpacing
            }
            // Horizontal lines
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += scaledSpacing
            }
            ctx.strokePath()

        case .dots:
            let dotSize: CGFloat = 2.0
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                var x: CGFloat = scaledSpacing
                while x < rect.width {
                    let dotRect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    ctx.fillEllipse(in: dotRect)
                    x += scaledSpacing
                }
                y += scaledSpacing
            }

        case .lines:
            ctx.setLineWidth(0.5)
            var y: CGFloat = scaledSpacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += scaledSpacing
            }
            ctx.strokePath()
        }
    }
}

// MARK: - PKCanvasViewDelegate

extension CanvasContainerView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let index = canvasViews.firstIndex(of: canvasView) else { return }
        let absolutePageIndex = pageIndexOffset + index
        drawingManager?.setDrawing(canvasView.drawing, for: absolutePageIndex)

        // Detect new stroke and report writing position
        let currentCount = canvasView.drawing.strokes.count
        let previousCount = lastStrokeCounts[index] ?? 0
        if currentCount > previousCount,
           let lastStroke = canvasView.drawing.strokes.last,
           lastStroke.path.count > 0 {
            let startPoint = lastStroke.path.interpolatedLocation(at: 0)
            // Canvas coordinates are at 2x render scale; divide by 2 for PDF points
            let yPDFPoints = startPoint.y / 2.0
            onWritingPositionChanged?(absolutePageIndex, yPDFPoints)
        }
        lastStrokeCounts[index] = currentCount
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        drawingManager?.activeCanvasView = canvasView
    }
}

// MARK: - Touch Tracking Canvas View

/// PKCanvasView subclass that reports Apple Pencil touch positions
/// via a closure, while still letting PencilKit handle all drawing.
final class TouchTrackingCanvasView: PKCanvasView {
    var onPencilTouch: ((_ location: CGPoint, _ phase: UITouch.Phase) -> Void)?
    var onAnyTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onAnyTouchBegan?()
        reportPencilTouch(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        reportPencilTouch(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        reportPencilTouch(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        for touch in touches where touch.type == .pencil {
            onPencilTouch?(touch.location(in: self), .cancelled)
        }
    }

    private func reportPencilTouch(_ touches: Set<UITouch>) {
        for touch in touches where touch.type == .pencil {
            onPencilTouch?(touch.location(in: self), touch.phase)
        }
    }
}
