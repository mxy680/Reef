import Foundation

// MARK: - Shape Templates for the $1 Unistroke Recognizer
//
// Multiple variants per shape improve matching across drawing styles.
// Points use arbitrary coordinate scales — the recognizer normalises them.

enum ShapeTemplates {
    static let all: [UnistrokeTemplate] = line + rectangle + circle + triangle + arrow

    // MARK: Line

    private static let line: [UnistrokeTemplate] = [
        // Left-to-right horizontal
        UnistrokeTemplate(
            name: "line",
            points: stride(from: 0.0, through: 100.0, by: 5.0).map { CGPoint(x: $0, y: 0) }
        ),
        // Top-to-bottom vertical
        UnistrokeTemplate(
            name: "line",
            points: stride(from: 0.0, through: 100.0, by: 5.0).map { CGPoint(x: 0, y: $0) }
        ),
        // Diagonal (top-left to bottom-right)
        UnistrokeTemplate(
            name: "line",
            points: stride(from: 0.0, through: 100.0, by: 5.0).map { CGPoint(x: $0, y: $0) }
        ),
        // Diagonal (top-right to bottom-left)
        UnistrokeTemplate(
            name: "line",
            points: stride(from: 0.0, through: 100.0, by: 5.0).map { CGPoint(x: 100.0 - $0, y: $0) }
        ),
    ]

    // MARK: Rectangle

    private static let rectangle: [UnistrokeTemplate] = [
        // Clockwise from top-left, landscape
        UnistrokeTemplate(name: "rectangle", points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 75), CGPoint(x: 0, y: 75), CGPoint(x: 0, y: 0),
        ]),
        // Clockwise from top-left, square
        UnistrokeTemplate(name: "rectangle", points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 0),
        ]),
        // Counter-clockwise from top-left, landscape
        UnistrokeTemplate(name: "rectangle", points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 75),
            CGPoint(x: 100, y: 75), CGPoint(x: 100, y: 0), CGPoint(x: 0, y: 0),
        ]),
        // Clockwise from top-right
        UnistrokeTemplate(name: "rectangle", points: [
            CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 75),
            CGPoint(x: 0, y: 75), CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
        ]),
        // Portrait (tall)
        UnistrokeTemplate(name: "rectangle", points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 75, y: 0),
            CGPoint(x: 75, y: 100), CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 0),
        ]),
    ]

    // MARK: Circle

    private static let circle: [UnistrokeTemplate] = [
        // Counter-clockwise full circle, 36 points
        UnistrokeTemplate(name: "circle", points: (0...36).map { i in
            let angle = CGFloat(i) / 36.0 * 2.0 * .pi
            return CGPoint(x: 50 + 50 * cos(angle), y: 50 + 50 * sin(angle))
        }),
        // Clockwise full circle
        UnistrokeTemplate(name: "circle", points: (0...36).map { i in
            let angle = -(CGFloat(i) / 36.0 * 2.0 * .pi)
            return CGPoint(x: 50 + 50 * cos(angle), y: 50 + 50 * sin(angle))
        }),
        // Ellipse wider than tall
        UnistrokeTemplate(name: "circle", points: (0...36).map { i in
            let angle = CGFloat(i) / 36.0 * 2.0 * .pi
            return CGPoint(x: 60 + 60 * cos(angle), y: 40 + 40 * sin(angle))
        }),
        // Ellipse taller than wide
        UnistrokeTemplate(name: "circle", points: (0...36).map { i in
            let angle = CGFloat(i) / 36.0 * 2.0 * .pi
            return CGPoint(x: 40 + 40 * cos(angle), y: 60 + 60 * sin(angle))
        }),
        // Starting from the left of the circle
        UnistrokeTemplate(name: "circle", points: (0...36).map { i in
            let angle = CGFloat(i) / 36.0 * 2.0 * .pi + .pi
            return CGPoint(x: 50 + 50 * cos(angle), y: 50 + 50 * sin(angle))
        }),
    ]

    // MARK: Triangle

    private static let triangle: [UnistrokeTemplate] = [
        // Clockwise from top apex
        UnistrokeTemplate(name: "triangle", points: [
            CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 87),
            CGPoint(x: 0, y: 87), CGPoint(x: 50, y: 0),
        ]),
        // Counter-clockwise from top apex
        UnistrokeTemplate(name: "triangle", points: [
            CGPoint(x: 50, y: 0), CGPoint(x: 0, y: 87),
            CGPoint(x: 100, y: 87), CGPoint(x: 50, y: 0),
        ]),
        // Starting from bottom-left
        UnistrokeTemplate(name: "triangle", points: [
            CGPoint(x: 0, y: 87), CGPoint(x: 100, y: 87),
            CGPoint(x: 50, y: 0), CGPoint(x: 0, y: 87),
        ]),
        // Starting from bottom-right
        UnistrokeTemplate(name: "triangle", points: [
            CGPoint(x: 100, y: 87), CGPoint(x: 50, y: 0),
            CGPoint(x: 0, y: 87), CGPoint(x: 100, y: 87),
        ]),
        // Right triangle
        UnistrokeTemplate(name: "triangle", points: [
            CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 0),
        ]),
    ]

    // MARK: Arrow

    private static let arrow: [UnistrokeTemplate] = [
        // Rightward: shaft then V-head
        UnistrokeTemplate(name: "arrow", points: [
            CGPoint(x: 0, y: 50), CGPoint(x: 80, y: 50),
            CGPoint(x: 65, y: 35), CGPoint(x: 80, y: 50), CGPoint(x: 65, y: 65),
        ]),
        // Leftward
        UnistrokeTemplate(name: "arrow", points: [
            CGPoint(x: 80, y: 50), CGPoint(x: 0, y: 50),
            CGPoint(x: 15, y: 35), CGPoint(x: 0, y: 50), CGPoint(x: 15, y: 65),
        ]),
        // Downward
        UnistrokeTemplate(name: "arrow", points: [
            CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 80),
            CGPoint(x: 35, y: 65), CGPoint(x: 50, y: 80), CGPoint(x: 65, y: 65),
        ]),
        // Upward
        UnistrokeTemplate(name: "arrow", points: [
            CGPoint(x: 50, y: 80), CGPoint(x: 50, y: 0),
            CGPoint(x: 35, y: 15), CGPoint(x: 50, y: 0), CGPoint(x: 65, y: 15),
        ]),
    ]
}
