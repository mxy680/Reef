//
//  CanvasDrawingToolbar.swift
//  Reef
//
//  Drawing tool and color enums used by the canvas toolbar
//

import SwiftUI

// MARK: - Canvas Tool

enum CanvasTool: String, CaseIterable {
    case pen
    case diagram
    case eraser
    case lasso
    case pan

    var icon: String {
        switch self {
        case .pen: "pencil.tip"
        case .diagram: "scribble.variable"
        case .eraser: "eraser.fill"
        case .lasso: "lasso"
        case .pan: "hand.draw.fill"
        }
    }
}
