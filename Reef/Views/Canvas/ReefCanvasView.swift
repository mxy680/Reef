//
//  ReefCanvasView.swift
//  Reef
//
//  Custom PKCanvasView subclass
//

import PencilKit
import UIKit

class ReefCanvasView: PKCanvasView {

    // MARK: - Eraser Cursor

    /// Whether the eraser tool is currently active
    var isEraserActive: Bool = false {
        didSet {
            if !isEraserActive {
                eraserCursorLayer.isHidden = true
            }
        }
    }

    /// Whether the custom stroke eraser is active (better hit detection than PKEraserTool)
    var isCustomStrokeEraserActive: Bool = false

    /// The eraser cursor diameter in canvas points
    var eraserCursorSize: CGFloat = 24 {
        didSet {
            updateCursorPath()
        }
    }

    private lazy var eraserCursorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = UIColor.systemGray.withAlphaComponent(0.6).cgColor
        layer.lineWidth = 1.5
        layer.isHidden = true
        self.layer.addSublayer(layer)
        return layer
    }()

    private func updateCursorPath() {
        let rect = CGRect(x: 0, y: 0, width: eraserCursorSize, height: eraserCursorSize)
        eraserCursorLayer.path = UIBezierPath(ovalIn: rect).cgPath
        eraserCursorLayer.bounds = rect
    }

    private func positionCursor(at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eraserCursorLayer.position = point
        CATransaction.commit()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard isEraserActive else { return }
        for touch in touches where touch.type == .pencil {
            let point = touch.location(in: self)
            updateCursorPath()
            positionCursor(at: point)
            eraserCursorLayer.isHidden = false
            if isCustomStrokeEraserActive {
                eraseStrokesAtPoint(point)
            }
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard isEraserActive, !eraserCursorLayer.isHidden else { return }
        for touch in touches where touch.type == .pencil {
            let point = touch.location(in: self)
            positionCursor(at: point)
            if isCustomStrokeEraserActive {
                // Use coalesced touches for smooth erasing across fast movements
                if let coalescedTouches = event?.coalescedTouches(for: touch) {
                    for coalescedTouch in coalescedTouches {
                        eraseStrokesAtPoint(coalescedTouch.location(in: self))
                    }
                } else {
                    eraseStrokesAtPoint(point)
                }
            }
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isEraserActive else { return }
        for touch in touches where touch.type == .pencil {
            if isCustomStrokeEraserActive {
                eraseStrokesAtPoint(touch.location(in: self))
            }
            eraserCursorLayer.isHidden = true
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard isEraserActive else { return }
        for touch in touches where touch.type == .pencil {
            eraserCursorLayer.isHidden = true
            break
        }
    }

    // MARK: - Custom Stroke Erasing

    /// Removes any strokes that intersect with the eraser circle at the given point.
    private func eraseStrokesAtPoint(_ point: CGPoint) {
        let radius = eraserCursorSize / 2
        let eraserRect = CGRect(
            x: point.x - radius, y: point.y - radius,
            width: eraserCursorSize, height: eraserCursorSize
        )

        var strokesToKeep: [PKStroke] = []
        var didErase = false

        for stroke in drawing.strokes {
            // Broad phase: skip strokes whose render bounds don't overlap the eraser area
            guard stroke.renderBounds.intersects(eraserRect) else {
                strokesToKeep.append(stroke)
                continue
            }

            // Narrow phase: check if any point on the stroke path is within eraser radius
            var intersects = false
            for pathPoint in stroke.path {
                let dx = pathPoint.location.x - point.x
                let dy = pathPoint.location.y - point.y
                let distSq = dx * dx + dy * dy
                // Account for the stroke's visual width at this point
                let strokeRadius = max(pathPoint.size.width, pathPoint.size.height) / 2
                let threshold = radius + strokeRadius
                if distSq < threshold * threshold {
                    intersects = true
                    break
                }
            }

            if intersects {
                didErase = true
            } else {
                strokesToKeep.append(stroke)
            }
        }

        if didErase {
            drawing = PKDrawing(strokes: strokesToKeep)
        }
    }
}
