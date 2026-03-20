import PencilKit
import UIKit

// MARK: - Recognized Shape

enum RecognizedShape {
    case line(start: CGPoint, end: CGPoint)
    case rectangle(CGRect, angle: CGFloat)
    case circle(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat)
    case triangle(CGPoint, CGPoint, CGPoint)
    case arrow(start: CGPoint, end: CGPoint, headAngle: CGFloat)
    case none

    var isNone: Bool {
        if case .none = self { return true }
        return false
    }
}

// MARK: - Shape Recognizer

struct ShapeRecognizer {

    // MARK: - Entry Point

    private static let recognizer: UnistrokeRecognizer = {
        UnistrokeRecognizer(templates: ShapeTemplates.all)
    }()

    private static let minimumConfidence: Double = 0.75

    static func recognize(stroke: PKStroke) -> RecognizedShape {
        guard stroke.path.count >= 5 else { return .none }
        let rawPoints = extractPoints(from: stroke)
        let totalLength = polylineLength(rawPoints)
        guard totalLength >= 20 else { return .none }

        guard let result = recognizer.recognize(rawPoints) else { return .none }
        print("[ShapeRecognizer] match=\(result.name) score=\(String(format: "%.2f", result.score))")
        guard result.score >= minimumConfidence else { return .none }

        // Map template name → RecognizedShape using geometric parameters from the original stroke.
        let points = resamplePoints(rawPoints, count: 50)

        switch result.name {
        case "line":
            return .line(start: rawPoints.first!, end: rawPoints.last!)

        case "rectangle":
            let corners = findCorners(points: points, count: 4)
            if corners.count == 4 {
                let pts = corners.map { points[$0] }
                let minX = pts.map(\.x).min()!
                let minY = pts.map(\.y).min()!
                let maxX = pts.map(\.x).max()!
                let maxY = pts.map(\.y).max()!
                let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                let angle = atan2(pts[1].y - pts[0].y, pts[1].x - pts[0].x)
                return .rectangle(rect, angle: angle)
            }
            // Fallback to axis-aligned bounding box
            let xs = rawPoints.map(\.x)
            let ys = rawPoints.map(\.y)
            let rect = CGRect(
                x: xs.min()!, y: ys.min()!,
                width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!
            )
            return .rectangle(rect, angle: 0)

        case "circle":
            let c = computeCentroid(points)
            let xs = rawPoints.map(\.x)
            let ys = rawPoints.map(\.y)
            let radiusX = (xs.max()! - xs.min()!) / 2.0
            let radiusY = (ys.max()! - ys.min()!) / 2.0
            return .circle(center: c, radiusX: radiusX, radiusY: radiusY)

        case "triangle":
            let corners = findCorners(points: points, count: 3)
            if corners.count == 3 {
                return .triangle(points[corners[0]], points[corners[1]], points[corners[2]])
            }
            return .none

        case "arrow":
            let start = rawPoints.first!
            // Approximate shaft end at 75 % of the stroke — head occupies the remaining 25 %.
            let shaftEnd = rawPoints[rawPoints.count * 3 / 4]
            let dir = CGPoint(x: shaftEnd.x - start.x, y: shaftEnd.y - start.y)
            return .arrow(start: start, end: shaftEnd, headAngle: atan2(dir.y, dir.x))

        default:
            return .none
        }
    }

    // MARK: - Build Clean Stroke

    static func buildStroke(for shape: RecognizedShape, template: PKStroke) -> PKStroke? {
        let ink = template.ink
        let transform = template.transform
        let avgForce: CGFloat
        let avgAltitude: CGFloat
        let avgAzimuth: CGFloat

        var forceSum: CGFloat = 0
        var altSum: CGFloat = 0
        var azSum: CGFloat = 0
        let count = template.path.count
        guard count > 0 else { return nil }

        for i in 0..<count {
            let pt = template.path[i]
            forceSum += pt.force
            altSum += pt.altitude
            azSum += pt.azimuth
        }
        avgForce = forceSum / CGFloat(count)
        avgAltitude = altSum / CGFloat(count)
        avgAzimuth = azSum / CGFloat(count)

        let geometryPoints: [CGPoint]
        switch shape {
        case .line(let start, let end):
            geometryPoints = [start, end]
        case .rectangle(let rect, let angle):
            geometryPoints = rectanglePoints(rect: rect, angle: angle)
        case .circle(let center, let rx, let ry):
            geometryPoints = ellipsePoints(center: center, radiusX: rx, radiusY: ry, count: 36)
        case .triangle(let a, let b, let c):
            geometryPoints = [a, b, c, a]
        case .arrow(let start, let end, let headAngle):
            geometryPoints = arrowPoints(start: start, end: end, headAngle: headAngle)
        case .none:
            return nil
        }

        guard geometryPoints.count >= 2 else { return nil }

        let strokePoints = makeStrokePoints(
            from: geometryPoints,
            force: avgForce,
            altitude: avgAltitude,
            azimuth: avgAzimuth
        )

        guard strokePoints.count >= 2 else { return nil }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: ink, path: path, transform: transform, mask: template.mask)
    }

    // MARK: - Geometry Utilities

    static func resamplePoints(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }
        let totalLen = polylineLength(points)
        guard totalLen > 0 else { return points }
        let interval = totalLen / CGFloat(count - 1)

        var result: [CGPoint] = [points[0]]
        var accumulated: CGFloat = 0
        var segmentIndex = 1

        while result.count < count - 1, segmentIndex < points.count {
            let segStart = points[segmentIndex - 1]
            let segEnd = points[segmentIndex]
            let segLen = distance(segStart, segEnd)

            let needed = interval - accumulated
            if segLen < needed {
                accumulated += segLen
                segmentIndex += 1
                continue
            }

            let t = needed / segLen
            let newPoint = CGPoint(
                x: segStart.x + t * (segEnd.x - segStart.x),
                y: segStart.y + t * (segEnd.y - segStart.y)
            )
            result.append(newPoint)
            accumulated = 0
        }

        result.append(points.last!)
        return result
    }

    static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return distance(point, lineStart) }
        return abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x) / len
    }

    static func angleBetween(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        guard mag1 > 0, mag2 > 0 else { return 0 }
        let cosAngle = max(-1, min(1, dot / (mag1 * mag2)))
        return acos(cosAngle)
    }

    static func polylineLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var length: CGFloat = 0
        for i in 1..<points.count {
            length += distance(points[i-1], points[i])
        }
        return length
    }

    // MARK: - Private Helpers

    private static func extractPoints(from stroke: PKStroke) -> [CGPoint] {
        var pts: [CGPoint] = []
        for i in 0..<stroke.path.count {
            pts.append(stroke.path[i].location)
        }
        return pts
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func computeCentroid(_ points: [CGPoint]) -> CGPoint {
        let n = CGFloat(points.count)
        let sumX = points.map { $0.x }.reduce(0, +)
        let sumY = points.map { $0.y }.reduce(0, +)
        return CGPoint(x: sumX / n, y: sumY / n)
    }

    private static func interiorAngle(vertex: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - vertex.x, y: p1.y - vertex.y)
        let v2 = CGPoint(x: p2.x - vertex.x, y: p2.y - vertex.y)
        return angleBetween(v1, v2)
    }

    /// Finds `count` corner indices by finding points with highest cumulative angle change.
    private static func findCorners(points: [CGPoint], count: Int) -> [Int] {
        guard points.count > count * 2 else { return [] }
        var angleChanges: [(index: Int, change: CGFloat)] = []
        let windowSize = max(1, points.count / (count * 4))

        for i in windowSize..<points.count - windowSize {
            let v1 = CGPoint(x: points[i].x - points[i - windowSize].x,
                             y: points[i].y - points[i - windowSize].y)
            let v2 = CGPoint(x: points[i + windowSize].x - points[i].x,
                             y: points[i + windowSize].y - points[i].y)
            let change = angleBetween(v1, v2)
            angleChanges.append((index: i, change: change))
        }

        // Sort by highest angle change and pick top `count`, then re-sort by index
        let sorted = angleChanges.sorted { $0.change > $1.change }
        let topN = sorted.prefix(count * 3)

        // Non-maximum suppression: filter out indices too close together
        let minDist = points.count / (count + 1)
        var selected: [Int] = []
        for entry in topN.sorted(by: { $0.change > $1.change }) {
            let tooClose = selected.contains { abs($0 - entry.index) < minDist }
            if !tooClose {
                selected.append(entry.index)
            }
            if selected.count == count { break }
        }

        return selected.sorted()
    }

    // MARK: - Geometry Point Builders

    private static func rectanglePoints(rect: CGRect, angle: CGFloat) -> [CGPoint] {
        let cx = rect.midX
        let cy = rect.midY
        let hw = rect.width / 2
        let hh = rect.height / 2

        let corners: [CGPoint] = [
            CGPoint(x: cx - hw, y: cy - hh),
            CGPoint(x: cx + hw, y: cy - hh),
            CGPoint(x: cx + hw, y: cy + hh),
            CGPoint(x: cx - hw, y: cy + hh),
        ]

        guard abs(angle) > 0.01 else {
            return corners + [corners[0]]
        }

        let cos = Foundation.cos(angle)
        let sin = Foundation.sin(angle)
        let rotated = corners.map { p -> CGPoint in
            let dx = p.x - cx
            let dy = p.y - cy
            return CGPoint(x: cx + dx * cos - dy * sin,
                           y: cy + dx * sin + dy * cos)
        }
        return rotated + [rotated[0]]
    }

    private static func ellipsePoints(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, count: Int) -> [CGPoint] {
        (0...count).map { i in
            let angle = CGFloat(i) / CGFloat(count) * 2 * CGFloat.pi
            return CGPoint(
                x: center.x + radiusX * Foundation.cos(angle),
                y: center.y + radiusY * Foundation.sin(angle)
            )
        }
    }

    private static func arrowPoints(start: CGPoint, end: CGPoint, headAngle: CGFloat) -> [CGPoint] {
        let headLength = distance(start, end) * 0.2
        let wingAngle: CGFloat = CGFloat.pi * 150.0 / 180.0  // 150° from shaft direction

        let leftWing = CGPoint(
            x: end.x + headLength * Foundation.cos(headAngle + wingAngle),
            y: end.y + headLength * Foundation.sin(headAngle + wingAngle)
        )
        let rightWing = CGPoint(
            x: end.x + headLength * Foundation.cos(headAngle - wingAngle),
            y: end.y + headLength * Foundation.sin(headAngle - wingAngle)
        )
        return [start, end, leftWing, end, rightWing]
    }

    private static func makeStrokePoints(
        from geometryPoints: [CGPoint],
        force: CGFloat,
        altitude: CGFloat,
        azimuth: CGFloat
    ) -> [PKStrokePoint] {
        geometryPoints.enumerated().map { idx, location in
            let t = geometryPoints.count > 1
                ? Double(idx) / Double(geometryPoints.count - 1)
                : 0
            return PKStrokePoint(
                location: location,
                timeOffset: t,
                size: CGSize(width: 1, height: 1),
                opacity: 1,
                force: force,
                azimuth: azimuth,
                altitude: altitude
            )
        }
    }
}
