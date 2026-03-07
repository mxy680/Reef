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

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.drawingManager = drawingManager
        container.pageIndexOffset = pageRange?.lowerBound ?? 0
        container.currentTool = currentTool
        container.configure(pdfDocument: pdfDocument, pageRange: pageRange)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.currentTool = currentTool
    }
}

// MARK: - Canvas Container View

final class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let pagesStackView = UIStackView()

    private var pageImageViews: [UIImageView] = []
    private var canvasViews: [PKCanvasView] = []
    private var separatorViews: [UIView] = []
    private var contentWidthConstraint: NSLayoutConstraint?

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
    }

    // MARK: - Configure

    func configure(pdfDocument: PDFDocument, pageRange: ClosedRange<Int>? = nil) {
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
        for view in separatorViews { view.removeFromSuperview() }
        pageImageViews.removeAll()
        canvasViews.removeAll()
        separatorViews.removeAll()
        pagesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

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

            // Page container — white background with rounded corners and border
            let pageView = UIView()
            pageView.translatesAutoresizingMaskIntoConstraints = false
            pageView.backgroundColor = .white
            pageView.layer.cornerRadius = Self.pageCornerRadius
            pageView.layer.borderWidth = 2
            pageView.layer.borderColor = Self.pageBorderColor.cgColor
            pageView.clipsToBounds = true
            wrapper.addSubview(pageView)

            let imageView = UIImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            pageView.addSubview(imageView)
            pageImageViews.append(imageView)

            // PKCanvasView overlay — transparent, on top of PDF image
            let canvasView = PKCanvasView()
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
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }
}

// MARK: - PKCanvasViewDelegate

extension CanvasContainerView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let index = canvasViews.firstIndex(of: canvasView) else { return }
        let absolutePageIndex = pageIndexOffset + index
        drawingManager?.setDrawing(canvasView.drawing, for: absolutePageIndex)
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        drawingManager?.activeCanvasView = canvasView
    }
}
