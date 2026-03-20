import PDFKit
import PencilKit
import UIKit

// MARK: - Canvas Export Service

enum CanvasExportService {

    static func exportPDF(
        pdfDocument: PDFDocument,
        drawings: [Int: PKDrawing],
        overlaySettings: CanvasOverlaySettings
    ) -> Data {
        let pageCount = pdfDocument.pageCount
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let mediaBox = page.bounds(for: .mediaBox)
            let pageRect = CGRect(origin: .zero, size: mediaBox.size)

            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            guard let ctx = UIGraphicsGetCurrentContext() else { continue }

            // 1. Draw the original PDF page
            // PDF coordinate system has origin at bottom-left; UIKit at top-left
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageRect.height)
            ctx.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()

            // 2. Draw overlay (only when showInExport is enabled)
            if overlaySettings.type != .none && overlaySettings.showInExport {
                drawOverlay(in: ctx, rect: pageRect, settings: overlaySettings)
            }

            // 3. Draw PencilKit drawings
            if let drawing = drawings[i], !drawing.strokes.isEmpty {
                let image = drawing.image(from: pageRect, scale: 1.0)
                image.draw(in: pageRect)
            }
        }

        UIGraphicsEndPDFContext()
        return data as Data
    }

    private static func drawOverlay(in ctx: CGContext, rect: CGRect, settings: CanvasOverlaySettings) {
        let spacing = settings.spacing
        let color = UIColor(white: 0.72, alpha: settings.opacity)

        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)

        switch settings.type {
        case .grid:
            ctx.setLineWidth(0.5)
            var x = spacing
            while x < rect.width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: rect.height))
                x += spacing
            }
            var y = spacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            ctx.strokePath()

        case .dots:
            let dotRadius: CGFloat = 1.0
            var x = spacing
            while x < rect.width {
                var y = spacing
                while y < rect.height {
                    ctx.fillEllipse(in: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                    y += spacing
                }
                x += spacing
            }

        case .lines:
            ctx.setLineWidth(0.5)
            var y = spacing
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            ctx.strokePath()

        case .none:
            break
        }

        ctx.restoreGState()
    }
}
