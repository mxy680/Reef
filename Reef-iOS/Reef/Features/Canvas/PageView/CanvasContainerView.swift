import UIKit
import PDFKit
import PencilKit

// MARK: - Canvas Container View (UIKit)

final class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let pagesStackView = UIStackView()

    private var pageImageViews: [UIImageView] = []
    private(set) var canvasViews: [PKCanvasView] = []
    private(set) var pageContainerViews: [UIView] = []
    private var shadowViews: [UIView] = []
    private var pageOverlayViews: [CanvasPageOverlayView] = []
    private var separatorViews: [UIView] = []
    private var pageWrappers: [UIView] = []
    private var contentWidthConstraint: NSLayoutConstraint?
    private var isDarkMode = false
    private(set) var currentPageVersion: Int = 0
    /// When true, setupPages will NOT save current canvas drawings back to the manager
    /// (because the manager was already shifted by insert/delete operations).
    var skipDrawingSaveOnRebuild = false

    /// Original rendered page images (light mode)
    private var originalImages: [UIImage] = []
    /// Color-inverted page images (dark mode) — lazily generated
    private var invertedImages: [UIImage]?

    /// Callback when pencil touches down on canvas (dismiss popovers)
    var onCanvasTouchBegan: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    var onStrokePositionChanged: ((_ pageIndex: Int, _ yPosition: Double) -> Void)?

    /// Drawing state manager
    weak var drawingManager: CanvasDrawingManager?

    /// Current PencilKit tool — updated from toolbar
    var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 2) {
        didSet {
            canvasViews.forEach { $0.tool = currentTool }
        }
    }

    /// Drawing policy — controls whether finger or only pencil can draw
    var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly {
        didSet {
            canvasViews.forEach { $0.drawingPolicy = drawingPolicy }
        }
    }

    /// Selected tool type — used to gate shape auto-snap
    var selectedToolType: CanvasToolType = .pen

    /// Prevents re-entrant delegate calls while replacing a stroke
    private var isReplacingStroke = false

    /// Tracks previous stroke counts per canvas view to detect new strokes
    private var previousStrokeCounts: [ObjectIdentifier: Int] = [:]

    /// Separator height between pages
    private static let separatorHeight: CGFloat = 16

    /// Corner radius for the 3D page cards
    private static let pageCornerRadius: CGFloat = 12

    /// 3D shadow offset
    private static let shadowOffset: CGFloat = 6

    /// Border color for pages — gray500
    private static let pageBorderColor = UIColor(red: 140/255.0, green: 140/255.0, blue: 140/255.0, alpha: 1)

    /// Scroll area background
    private static let scrollBackground = UIColor(
        red: 0xF8 / 255.0, green: 0xF0 / 255.0, blue: 0xE6 / 255.0, alpha: 1
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bouncesZoom = true
        scrollView.delegate = self
        scrollView.backgroundColor = Self.scrollBackground
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

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
    }

    // MARK: - Configure

    func configure(pdfDocument: PDFDocument, pageVersion: Int = 0) {
        currentPageVersion = pageVersion
        Task { [weak self] in
            guard let self else { return }
            let images = await self.renderPDFPages(document: pdfDocument)

            await MainActor.run {
                self.setupPages(with: images)
                DispatchQueue.main.async {
                    self.centerAndFitDocument()
                }
            }
        }
    }

    // MARK: - Scroll To Page

    func scrollToPage(_ index: Int, animated: Bool = true) {
        guard index >= 0, index < pageWrappers.count else { return }
        let wrapper = pageWrappers[index]
        // Convert wrapper frame to scroll view's content coordinate space
        let frameInContent = wrapper.convert(wrapper.bounds, to: contentView)
        let targetRect = CGRect(
            x: frameInContent.minX,
            y: frameInContent.minY - 20,
            width: frameInContent.width,
            height: frameInContent.height + 20
        )
        scrollView.scrollRectToVisible(targetRect, animated: animated)
    }

    // MARK: - Overlay

    private var currentOverlayType: CanvasOverlayType = .none
    private var currentOverlaySpacing: CGFloat = 20
    private var currentOverlayOpacity: CGFloat = 0.35

    func updateOverlay(type: CanvasOverlayType, spacing: CGFloat, opacity: CGFloat) {
        guard type != currentOverlayType || spacing != currentOverlaySpacing || opacity != currentOverlayOpacity else { return }
        currentOverlayType = type
        currentOverlaySpacing = spacing
        currentOverlayOpacity = opacity

        for overlay in pageOverlayViews {
            overlay.overlayType = type
            overlay.spacing = spacing
            overlay.overlayOpacity = opacity
            overlay.setNeedsDisplay()
        }
    }

    // MARK: - Render PDF

    private func renderPDFPages(document: PDFDocument) async -> [UIImage] {
        let scale: CGFloat = 2.0
        var images: [UIImage] = []

        guard document.pageCount > 0 else { return images }
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let mediaBox = page.bounds(for: .mediaBox)
            // Account for page rotation
            let pageSize: CGSize
            if page.rotation == 90 || page.rotation == 270 {
                pageSize = CGSize(width: mediaBox.height, height: mediaBox.width)
            } else {
                pageSize = mediaBox.size
            }

            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
            )
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
                // Compensate for non-zero mediaBox origin + flip Y for PDF coordinates
                ctx.cgContext.translateBy(
                    x: -mediaBox.origin.x * scale,
                    y: pageSize.height * scale + mediaBox.origin.y * scale
                )
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            // IMPORTANT: scale:2.0 so image.size returns PDF point dimensions.
            // PKCanvasView is sized to image.size, so strokes are in PDF point space.
            let scaledImage = UIImage(cgImage: image.cgImage!, scale: scale, orientation: .up)
            images.append(scaledImage)
        }

        return images
    }

    // MARK: - Setup Pages

    private func setupPages(with images: [UIImage]) {
        // Save current drawings before rebuilding pages — skip if drawings were
        // already shifted by an insert/delete operation (prevents overwriting the shift)
        if !skipDrawingSaveOnRebuild {
            for (index, canvasView) in canvasViews.enumerated() {
                drawingManager?.setDrawing(canvasView.drawing, for: index)
            }
        }
        skipDrawingSaveOnRebuild = false

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
        pagesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        originalImages = images
        invertedImages = nil

        for (index, image) in images.enumerated() {
            // Wrapper holds shadow + page
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.backgroundColor = .clear

            // 3D shadow
            let shadowView = UIView()
            shadowView.translatesAutoresizingMaskIntoConstraints = false
            shadowView.backgroundColor = Self.pageBorderColor
            shadowView.layer.cornerRadius = Self.pageCornerRadius
            wrapper.addSubview(shadowView)
            shadowViews.append(shadowView)

            // Page container
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

            // PKCanvasView overlay
            let canvasView = CanvasTouchTrackingView()
            canvasView.onAnyTouchBegan = { [weak self] in
                self?.onCanvasTouchBegan?()
            }
            canvasView.translatesAutoresizingMaskIntoConstraints = false
            canvasView.backgroundColor = .clear
            canvasView.isOpaque = false
            canvasView.drawingPolicy = self.drawingPolicy
            canvasView.tool = currentTool
            canvasView.delegate = self
            canvasView.overrideUserInterfaceStyle = .light
            canvasView.isScrollEnabled = false

            if let manager = drawingManager {
                canvasView.drawing = manager.drawing(for: index)
            }

            // Page overlay (added before canvas so drawing renders on top)
            let overlayView = CanvasPageOverlayView()
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            overlayView.isUserInteractionEnabled = false
            overlayView.overlayType = currentOverlayType
            overlayView.spacing = currentOverlaySpacing
            overlayView.overlayOpacity = currentOverlayOpacity
            pageView.addSubview(overlayView)
            pageOverlayViews.append(overlayView)

            // Canvas view (on top of overlay so strokes are visible)
            pageView.addSubview(canvasView)
            canvasViews.append(canvasView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),

                overlayView.topAnchor.constraint(equalTo: pageView.topAnchor),
                overlayView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                overlayView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),

                canvasView.topAnchor.constraint(equalTo: pageView.topAnchor),
                canvasView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                canvasView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                canvasView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])

            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                pageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                pageView.widthAnchor.constraint(equalToConstant: image.size.width),
                pageView.heightAnchor.constraint(equalToConstant: image.size.height),
            ])

            NSLayoutConstraint.activate([
                shadowView.topAnchor.constraint(equalTo: pageView.topAnchor, constant: Self.shadowOffset),
                shadowView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: Self.shadowOffset),
                shadowView.widthAnchor.constraint(equalTo: pageView.widthAnchor),
                shadowView.heightAnchor.constraint(equalTo: pageView.heightAnchor),
            ])

            NSLayoutConstraint.activate([
                wrapper.widthAnchor.constraint(equalToConstant: image.size.width + Self.shadowOffset),
                wrapper.heightAnchor.constraint(equalToConstant: image.size.height + Self.shadowOffset),
            ])

            pagesStackView.addArrangedSubview(wrapper)
            pageWrappers.append(wrapper)

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

        let targetImages: [UIImage]
        if dark {
            if invertedImages == nil {
                invertedImages = originalImages.map { Self.invertImage($0) }
            }
            targetImages = invertedImages!
        } else {
            targetImages = originalImages
        }

        for canvasView in canvasViews {
            canvasView.overrideUserInterfaceStyle = dark ? .dark : .light
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

        let horizontalPadding: CGFloat = 80
        let availableWidth = viewportSize.width - horizontalPadding
        let zoomToFitWidth = availableWidth / contentWidth
        let targetZoom = min(max(zoomToFitWidth, scrollView.minimumZoomScale), scrollView.maximumZoomScale)

        scrollView.zoomScale = targetZoom

        setNeedsLayout()
        layoutIfNeeded()

        scrollView.contentOffset = CGPoint(
            x: -scrollView.contentInset.left,
            y: -scrollView.contentInset.top - 20
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let minTopPadding: CGFloat = 40
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, minTopPadding)
        scrollView.contentInset = UIEdgeInsets(
            top: offsetY, left: offsetX,
            bottom: offsetY, right: offsetX
        )
    }
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
        onZoomChanged?(scrollView.zoomScale)
    }
}

// MARK: - PKCanvasViewDelegate

extension CanvasContainerView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let index = canvasViews.firstIndex(of: canvasView) else { return }

        // 1. Report stroke position FIRST so ViewModel updates activeQuestionLabel
        //    before transcription is triggered by onDrawingChanged
        if let lastStroke = canvasView.drawing.strokes.last {
            let screenScale = canvasView.window?.screen.scale ?? 2.0
            let midY = Double(lastStroke.renderBounds.midY) / screenScale
            onStrokePositionChanged?(index, midY)
        }

        // 2. THEN update drawing — this triggers onDrawingChanged which reads
        //    the now-current activeQuestionLabel for region filtering
        drawingManager?.setDrawing(canvasView.drawing, for: index)

        // Shape auto-snap via server
        guard !isReplacingStroke else { return }
        guard selectedToolType == .shapes else { return }

        let currentCount = canvasView.drawing.strokes.count
        let viewId = ObjectIdentifier(canvasView)
        let previousCount = previousStrokeCounts[viewId] ?? 0
        previousStrokeCounts[viewId] = currentCount

        guard currentCount == previousCount + 1 else { return }
        guard let lastStroke = canvasView.drawing.strokes.last else { return }

        let strokeIndex = currentCount - 1

        Task { @MainActor [weak self] in
            guard let self else { return }

            let shape = await ShapeRecognizer.recognizeRemote(stroke: lastStroke)
            guard !shape.isNone,
                  let cleanStroke = ShapeRecognizer.buildStroke(for: shape, template: lastStroke)
            else { return }

            // Re-validate stroke is still at expected index
            guard canvasView.drawing.strokes.count > strokeIndex else { return }

            self.isReplacingStroke = true
            var newDrawing = canvasView.drawing
            newDrawing.strokes[strokeIndex] = cleanStroke
            canvasView.drawing = newDrawing
            self.isReplacingStroke = false

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // Update drawing manager
            if let idx = self.canvasViews.firstIndex(of: canvasView) {
                self.drawingManager?.setDrawing(canvasView.drawing, for: idx)
            }
        }
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        drawingManager?.activeCanvasView = canvasView
    }
}

// MARK: - Touch Tracking Canvas View

final class CanvasTouchTrackingView: PKCanvasView {
    var onAnyTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onAnyTouchBegan?()
    }
}
