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

    /// Whether the eraser tool is currently active (bitmap only)
    var isEraserActive: Bool = false {
        didSet {
            if !isEraserActive {
                eraserCursorLayer.isHidden = true
            }
        }
    }

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
            updateCursorPath()
            positionCursor(at: touch.location(in: self))
            eraserCursorLayer.isHidden = false
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard isEraserActive, !eraserCursorLayer.isHidden else { return }
        for touch in touches where touch.type == .pencil {
            positionCursor(at: touch.location(in: self))
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isEraserActive else { return }
        for touch in touches where touch.type == .pencil {
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
}
