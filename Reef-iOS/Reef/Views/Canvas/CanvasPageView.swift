//
//  CanvasPageView.swift
//  Reef
//
//  Renders all PDF pages vertically stacked in a zoomable scroll view
//

import SwiftUI
import PDFKit

struct CanvasPageView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    let pageRange: ClosedRange<Int>?
    var overlaySettings: PageOverlaySettings = PageOverlaySettings()

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        container.configure(pdfDocument: pdfDocument, pageRange: pageRange)
        container.updateOverlay(overlaySettings)
        return container
    }

    func updateUIView(_ uiView: CanvasContainerView, context: Context) {
        uiView.updateOverlay(overlaySettings)
    }
}

// MARK: - Canvas Container View

final class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let pagesStackView = UIStackView()

    private var pageImageViews: [UIImageView] = []
    private var pageOverlayViews: [PageOverlayView] = []
    private var separatorViews: [UIView] = []
    private var contentWidthConstraint: NSLayoutConstraint?
    private var currentOverlaySettings = PageOverlaySettings()

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

    // MARK: - Overlay

    func updateOverlay(_ settings: PageOverlaySettings) {
        guard settings != currentOverlaySettings else { return }
        currentOverlaySettings = settings

        for overlay in pageOverlayViews {
            overlay.overlayType = settings.type
            overlay.spacing = settings.spacing
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
        for view in pageOverlayViews { view.removeFromSuperview() }
        for view in separatorViews { view.removeFromSuperview() }
        pageImageViews.removeAll()
        pageOverlayViews.removeAll()
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

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
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

// MARK: - Page Overlay View

final class PageOverlayView: UIView {
    var overlayType: PageOverlayType = .none
    var spacing: CGFloat = 20

    private static let overlayColor = UIColor(white: 0.72, alpha: 0.35)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard overlayType != .none else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setStrokeColor(Self.overlayColor.cgColor)
        ctx.setFillColor(Self.overlayColor.cgColor)

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
