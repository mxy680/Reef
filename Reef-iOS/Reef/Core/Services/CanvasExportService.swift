import PDFKit
import PencilKit
import UIKit

// MARK: - Canvas Export Service

enum CanvasExportService {

    /// Export by screenshotting each page view from the container.
    /// This guarantees WYSIWYG — the export matches exactly what the user sees.
    @MainActor
    static func exportFromContainer(_ containerView: CanvasContainerView) -> Data {
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)

        for (index, pageContainer) in containerView.pageContainerViews.enumerated() {
            let size = pageContainer.bounds.size
            guard size.width > 0, size.height > 0 else { continue }

            // Screenshot the page container (includes PDF image + overlay + PKCanvasView drawing)
            let renderer = UIGraphicsImageRenderer(size: size)
            let pageImage = renderer.image { ctx in
                pageContainer.drawHierarchy(in: pageContainer.bounds, afterScreenUpdates: false)
            }

            let pageRect = CGRect(origin: .zero, size: size)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            pageImage.draw(in: pageRect)
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }
}
