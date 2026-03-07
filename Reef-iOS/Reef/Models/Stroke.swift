//
//  Stroke.swift
//  Reef
//
//  DEPRECATED: Custom drawing model replaced by PencilKit (PKDrawing/PKStroke/PKStrokePoint).
//  Kept temporarily for reference. Safe to delete once confirmed unused.
//

import UIKit

// MARK: - Stroke Point

@available(*, deprecated, message: "Use PKStrokePoint instead")
struct StrokePoint: Codable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let force: CGFloat

    var location: CGPoint { CGPoint(x: x, y: y) }

    init(location: CGPoint, force: CGFloat = 1.0) {
        self.x = location.x
        self.y = location.y
        self.force = force
    }
}

// MARK: - Stroke Color

@available(*, deprecated, message: "Use UIColor directly with PKInkingTool instead")
struct StrokeColor: Codable, Sendable, Hashable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    static let black = StrokeColor(uiColor: .black)
    static let blue = StrokeColor(uiColor: UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
    static let red = StrokeColor(uiColor: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1))
    static let green = StrokeColor(uiColor: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1))
    static let orange = StrokeColor(uiColor: UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1))
}

// MARK: - Drawing Tool

@available(*, deprecated, message: "Use CanvasTool.pkTool() instead")
enum DrawingTool: String, Codable, Sendable {
    case pen
    case highlighter
    case eraser
}

// MARK: - Stroke

@available(*, deprecated, message: "Use PKStroke instead")
struct Stroke: Codable, Identifiable, Sendable {
    let id: UUID
    let tool: DrawingTool
    let color: StrokeColor
    let lineWidth: CGFloat
    var points: [StrokePoint]

    init(tool: DrawingTool, color: StrokeColor, lineWidth: CGFloat, points: [StrokePoint] = []) {
        self.id = UUID()
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
    }
}

// MARK: - Page Drawing

@available(*, deprecated, message: "Use PKDrawing instead")
struct PageDrawing: Codable, Sendable {
    var strokes: [Stroke]

    init(strokes: [Stroke] = []) {
        self.strokes = strokes
    }
}

// MARK: - Drawing Action

@available(*, deprecated, message: "Use PKCanvasView's UndoManager instead")
enum DrawingAction: Sendable {
    case addStroke(Stroke)
    case eraseStrokes(remaining: [Stroke])
}
