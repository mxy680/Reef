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
    case highlighter
    case eraser
    case lasso

    var icon: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }

    /// Whether this tool supports color selection
    var hasColorPalette: Bool {
        self == .pen || self == .highlighter
    }
}

// MARK: - Toolbar Color

/// Colors available in the toolbar palette, matching StrokeColor presets
enum ToolbarColor: CaseIterable {
    case black, blue, red, green, orange

    var color: Color {
        switch self {
        case .black: .black
        case .blue: Color(red: 0.2, green: 0.4, blue: 0.9)
        case .red: Color(red: 0.9, green: 0.2, blue: 0.2)
        case .green: Color(red: 0.2, green: 0.7, blue: 0.3)
        case .orange: Color(red: 0.95, green: 0.6, blue: 0.1)
        }
    }
}
