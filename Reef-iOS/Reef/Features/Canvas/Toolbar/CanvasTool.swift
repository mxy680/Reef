import PencilKit

// MARK: - Canvas Tool

enum CanvasToolType: String, CaseIterable {
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

    var hasSettings: Bool {
        switch self {
        case .pen, .diagram, .eraser: true
        case .lasso: false
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

enum CanvasOverlayType: String, CaseIterable {
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

struct CanvasOverlaySettings: Equatable {
    var type: CanvasOverlayType = .none
    var spacing: CGFloat = 20
    var opacity: CGFloat = 0.35
    var showInExport: Bool = false
}
