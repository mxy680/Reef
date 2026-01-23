//
//  DrawingOverlayView.swift
//  Reef
//
//  PencilKit canvas overlay for document annotation
//

import SwiftUI
import PencilKit
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct DrawingOverlayView: UIViewRepresentable {
    let documentURL: URL
    let fileType: Note.FileType
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: Color
    @Binding var penWidth: StrokeWidth
    @Binding var highlighterWidth: StrokeWidth
    @Binding var eraserSize: EraserSize
    var isDarkMode: Bool = false
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }
    var onSelectionChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentURL: documentURL, fileType: fileType, isDarkMode: isDarkMode)
        container.canvasView.delegate = context.coordinator
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged
        context.coordinator.onSelectionChanged = onSelectionChanged
        updateTool(container.canvasView)

        // Notify parent that canvas is ready
        DispatchQueue.main.async {
            onCanvasReady(container)
        }

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        updateTool(container.canvasView)
    }

    private func updateTool(_ canvasView: PKCanvasView) {
        switch selectedTool {
        case .pen:
            let uiColor = UIColor(selectedColor)
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: penWidth.rawValue)
        case .highlighter:
            let uiColor = UIColor(selectedColor).withAlphaComponent(0.3)
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: highlighterWidth.rawValue * 3)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector, width: eraserSize.rawValue)
        case .lasso:
            canvasView.tool = PKLassoTool()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var container: CanvasContainerView?
        var onUndoStateChanged: (Bool) -> Void = { _ in }
        var onRedoStateChanged: (Bool) -> Void = { _ in }
        var onSelectionChanged: (Bool) -> Void = { _ in }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            checkSelectionState(canvasView)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
            checkSelectionState(canvasView)
        }

        private func updateUndoRedoState(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.onUndoStateChanged(canvasView.undoManager?.canUndo ?? false)
                self?.onRedoStateChanged(canvasView.undoManager?.canRedo ?? false)
            }
        }

        private func checkSelectionState(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                let hasContent = !canvasView.drawing.strokes.isEmpty
                // Show selection options when lasso is active and there's content
                self?.onSelectionChanged(hasContent && canvasView.tool is PKLassoTool)
            }
        }
    }
}

// MARK: - Canvas Container with Zoom and Pan

class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()  // Container for document + canvas
    let documentImageView = UIImageView()
    let canvasView = PKCanvasView()

    private var documentURL: URL?
    private var fileType: Note.FileType?
    private var isDarkMode: Bool = false

    /// Light gray background for scroll view in light mode (close to white)
    private static let scrollBackgroundLight = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Lighter background for scroll area in dark mode (lighter than the page)
    private static let scrollBackgroundDark = UIColor(red: 18/255, green: 32/255, blue: 52/255, alpha: 1)

    convenience init(documentURL: URL, fileType: Note.FileType, isDarkMode: Bool = false) {
        self.init(frame: .zero)
        self.documentURL = documentURL
        self.fileType = fileType
        self.isDarkMode = isDarkMode
        loadDocument()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = Self.scrollBackgroundLight  // Updated in loadDocument for dark mode
        addSubview(scrollView)

        // Configure content view (holds both document and canvas)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.25
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 12
        scrollView.addSubview(contentView)

        // Configure document image view
        documentImageView.translatesAutoresizingMaskIntoConstraints = false
        documentImageView.contentMode = .scaleAspectFit
        documentImageView.backgroundColor = .white
        contentView.addSubview(documentImageView)

        // Configure canvas view (transparent overlay)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvasView)

        // Layout constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            // Document and canvas fill the content view
            documentImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            documentImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            documentImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            documentImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func loadDocument() {
        guard let url = documentURL, let fileType = fileType else { return }

        // Update backgrounds based on dark mode
        // Scroll area uses sage mist (light) or black (dark), page is white (light) or deep ocean (dark)
        scrollView.backgroundColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        let pageBgColor: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        contentView.backgroundColor = pageBgColor
        documentImageView.backgroundColor = pageBgColor

        // Adjust shadow for dark mode - use subtle glow effect
        if isDarkMode {
            contentView.layer.shadowColor = UIColor(white: 0.4, alpha: 1).cgColor
            contentView.layer.shadowOpacity = 0.3
            contentView.layer.shadowRadius = 16
        } else {
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.25
            contentView.layer.shadowRadius = 12
        }

        Task { [weak self] in
            let loadedImage: UIImage? = await {
                switch fileType {
                case .pdf:
                    return await self?.renderPDFToImage(url: url)
                case .image:
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                    return nil
                case .document:
                    return nil
                }
            }()

            await MainActor.run { [weak self, loadedImage] in
                guard let self = self, let image = loadedImage else { return }
                self.documentImageView.image = image
                self.updateContentSize(for: image.size)
            }
        }
    }

    private func renderPDFToImage(url: URL) async -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0  // Retina quality

        let renderer = UIGraphicsImageRenderer(size: CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        ))

        let normalImage = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            context.cgContext.translateBy(x: 0, y: pageRect.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        // In dark mode, apply false color filter to invert: black text → white, white bg → Deep Ocean
        if isDarkMode {
            return applyDarkModeFilter(to: normalImage)
        }

        return normalImage
    }

    /// Applies false color filter to convert light mode PDF to dark mode
    /// Maps black (text) → white, white (background) → Deep Ocean
    private func applyDarkModeFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = ciImage
        // color0: Black pixels (text) → White for readability
        falseColor.color0 = CIColor(red: 1, green: 1, blue: 1)
        // color1: White pixels (background) → Deep Ocean (#0A1628)
        falseColor.color1 = CIColor(red: 10/255, green: 22/255, blue: 40/255)

        guard let outputImage = falseColor.outputImage else { return image }

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private var contentWidthConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?

    private func updateContentSize(for imageSize: CGSize) {
        // Remove old constraints
        contentWidthConstraint?.isActive = false
        contentHeightConstraint?.isActive = false

        // Set content size based on document
        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: imageSize.width)
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: imageSize.height)

        contentWidthConstraint?.isActive = true
        contentHeightConstraint?.isActive = true

        layoutIfNeeded()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Center content if smaller than scroll view
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }
}

#Preview {
    DrawingOverlayView(
        documentURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        fileType: .pdf,
        selectedTool: .constant(.pen),
        selectedColor: .constant(.inkBlack),
        penWidth: .constant(.medium),
        highlighterWidth: .constant(.medium),
        eraserSize: .constant(.medium)
    )
    .background(Color.gray.opacity(0.2))
}
