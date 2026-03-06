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

    var icon: String {
        switch self {
        case .pen: "pencil.tip"
        case .diagram: "canvas.diagram"
        case .eraser: "canvas.eraser"
        case .lasso: "lasso"
        }
    }

    var isCustomIcon: Bool {
        switch self {
        case .diagram, .eraser: true
        case .pen, .lasso: false
        }
    }
}
