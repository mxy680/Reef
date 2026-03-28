#if DEBUG
import PencilKit

// MARK: - Simulation Stroke Renderer

/// Converts server stroke data to PKStrokes and animates them onto the canvas.
@MainActor
final class SimulationStrokeRenderer {

    // MARK: - Build

    /// Convert server stroke data to PKStrokes scaled to fit within targetRect.
    ///
    /// Server stroke format: `[{"x": [50.0, 51.0, ...], "y": [100.0, 101.0, ...]}]`
    /// Each dict is one stroke; x and y arrays are zipped into CGPoints.
    static func buildStrokes(from data: [[String: [Double]]], targetRect: CGRect) -> [PKStroke] {
        guard !data.isEmpty else { return [] }

        // Collect all points to find bounding box
        var allX: [Double] = []
        var allY: [Double] = []
        for strokeDict in data {
            if let xs = strokeDict["x"], let ys = strokeDict["y"] {
                allX.append(contentsOf: xs)
                allY.append(contentsOf: ys)
            }
        }

        guard let minX = allX.min(), let maxX = allX.max(),
              let minY = allY.min(), let maxY = allY.max() else { return [] }

        let bboxWidth = maxX - minX
        let bboxHeight = maxY - minY

        // Avoid division by zero; use a minimum size
        let safeWidth = bboxWidth > 0 ? bboxWidth : 1
        let safeHeight = bboxHeight > 0 ? bboxHeight : 1

        // Scale to fit inside targetRect while preserving aspect ratio
        let scaleX = targetRect.width / safeWidth
        let scaleY = targetRect.height / safeHeight
        let scale = min(scaleX, scaleY)

        let ink = PKInk(.pen, color: .black)

        return data.compactMap { strokeDict -> PKStroke? in
            guard let xs = strokeDict["x"], let ys = strokeDict["y"],
                  !xs.isEmpty, xs.count == ys.count else { return nil }

            let points = zip(xs, ys).enumerated().map { idx, pair in
                let (x, y) = pair
                let scaledX = targetRect.origin.x + CGFloat((x - minX) * scale)
                let scaledY = targetRect.origin.y + CGFloat((y - minY) * scale)
                return PKStrokePoint(
                    location: CGPoint(x: scaledX, y: scaledY),
                    timeOffset: TimeInterval(idx) * 0.01,
                    size: CGSize(width: 2, height: 2),
                    opacity: 1,
                    force: 0.5,
                    azimuth: 0,
                    altitude: .pi / 4
                )
            }

            let path = PKStrokePath(controlPoints: points, creationDate: Date())
            return PKStroke(ink: ink, path: path)
        }
    }

    // MARK: - Animate

    /// Animate strokes onto a canvas, one stroke at a time with a delay between each.
    static func animateStrokes(
        _ strokes: [PKStroke],
        onto drawingManager: CanvasDrawingManager,
        pageIndex: Int,
        delayPerStroke: Duration = .milliseconds(200)
    ) async {
        guard let canvasView = drawingManager.activeCanvasView else {
            print("[simulation] ERROR: activeCanvasView is nil, cannot render strokes")
            // Still store in drawing manager so transcription can pick them up
            var drawing = drawingManager.drawing(for: pageIndex)
            for stroke in strokes { drawing.strokes.append(stroke) }
            drawingManager.setDrawing(drawing, for: pageIndex)
            return
        }

        print("[simulation] Animating \(strokes.count) strokes on canvasView (frame: \(canvasView.frame))")

        for stroke in strokes {
            // Get current drawing from the canvas view directly
            var drawing = canvasView.drawing
            drawing.strokes.append(stroke)
            canvasView.drawing = drawing
            // Also sync to drawing manager
            drawingManager.setDrawing(drawing, for: pageIndex)
            try? await Task.sleep(for: delayPerStroke)
        }
    }
}
#endif
