//
//  CanvasPageView.swift
//  Reef
//
//  Renders a single PDF page in a zoomable scroll view
//

import SwiftUI
import PDFKit

struct CanvasPageView: UIViewRepresentable {
    let pdfPage: PDFPage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFScrollView {
        let scrollView = PDFScrollView()
        scrollView.configure(pdfPage: pdfPage, coordinator: context.coordinator)
        return scrollView
    }

    func updateUIView(_ uiView: PDFScrollView, context: Context) {}

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? PDFScrollView)?.contentContainer
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let container = (scrollView as? PDFScrollView)?.contentContainer else { return }
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
    }
}

// MARK: - PDF Scroll View

final class PDFScrollView: UIScrollView {
    let contentContainer = UIView()
    private let pdfImageView = UIImageView()
    private var hasSetInitialZoom = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false

        addSubview(contentContainer)
        contentContainer.addSubview(pdfImageView)
        pdfImageView.contentMode = .scaleToFill
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(pdfPage: PDFPage, coordinator: CanvasPageView.Coordinator) {
        delegate = coordinator
        hasSetInitialZoom = false

        let pageRect = pdfPage.bounds(for: .mediaBox)

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
