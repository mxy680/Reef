import PencilKit

// MARK: - Canvas Tool

enum CanvasToolType: String, CaseIterable {
    case pen
    case highlighter
    case shapes
    case lasso
    case handDraw
    case diagram
    case eraser

    var icon: String {
        switch self {
        case .pen: "canvas.pen"
        case .highlighter: "canvas.highlighter"
        case .shapes: "canvas.shapes"
        case .lasso: "canvas.lasso"
        case .handDraw: "canvas.hand_draw"
        case .diagram: "canvas.diagram"
        case .eraser: "canvas.eraser_new"
        }
    }

    var isCustomIcon: Bool {
        switch self {
        case .pen, .highlighter, .shapes, .lasso, .handDraw, .diagram, .eraser: true
        }
    }

    var hasSettings: Bool {
        switch self {
        case .pen, .highlighter, .diagram, .eraser: true
        case .shapes, .lasso, .handDraw: false
        }
    }

    func pkTool(
        color: UIColor = .black,
        width: CGFloat = 2.0,
        eraserType: PKEraserTool.EraserType = .vector,
        eraserWidth: CGFloat = 8.0
    ) -> PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .highlighter:
            return PKInkingTool(.marker, color: color.withAlphaComponent(0.3), width: width * 6)
        case .shapes, .handDraw:
            return PKInkingTool(.pen, color: color, width: width)
        case .diagram:
            return PKInkingTool(.monoline, color: color, width: width * 2)
        case .eraser:
            return PKEraserTool(eraserType, width: eraserWidth)
        case .lasso:
            return PKLassoTool()
        }
    }
}

// MARK: - Page Overlay Settings

enum CanvasOverlayType: String, CaseIterable, Codable {
    case none, grid, dots, lines

    var label: String {
        switch self {
        case .none:  "None"
        case .grid:  "Grid"
        case .dots:  "Dots"
        case .lines: "Lines"
        }
    }
}

struct CanvasOverlaySettings: Equatable, Codable {
    var type: CanvasOverlayType = .none
    var spacing: CGFloat = 20
    var opacity: CGFloat = 0.525
    var showInExport: Bool = false
}
