//
//  CanvasDrawingToolbar.swift
//  Reef
//
//  Drawing tool and color enums used by the canvas toolbar
//

import SwiftUI
import PencilKit

// MARK: - Canvas Tool

enum CanvasTool: String, CaseIterable {
    case pen
    case diagram
    case eraser
    case lasso

    var icon: String {
        switch self {
        case .pen: "pencil.tip"
        case .diagram: "canvas.diagram"
        case .eraser: "eraser.fill"
        case .lasso: "lasso"
        }
    }

    var isCustomIcon: Bool {
        switch self {
        case .diagram: true
        case .pen, .eraser, .lasso: false
        }
    }

    /// Whether this tool has color/thickness settings
    var hasSettings: Bool {
        switch self {
        case .pen, .diagram: true
        case .eraser, .lasso: false
        }
    }

    /// Convert to PencilKit tool
    func pkTool(color: UIColor = .black, width: CGFloat = 2.0) -> PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .diagram:
            return PKInkingTool(.monoline, color: color, width: width * 2)
        case .eraser:
            return PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        }
    }
}
