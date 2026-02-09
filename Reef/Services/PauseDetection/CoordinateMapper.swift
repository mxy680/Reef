//
//  CoordinateMapper.swift
//  Reef
//
//  Converts canvas coordinates to PDF points for region mapping
//

import CoreGraphics

enum CoordinateMapper {
    /// Must match the scale in CanvasContainerView.renderPDFPages
    static let renderScale: CGFloat = 2.0

    static func canvasToPDFY(_ canvasY: CGFloat) -> Float {
        Float(canvasY / renderScale)
    }
}
