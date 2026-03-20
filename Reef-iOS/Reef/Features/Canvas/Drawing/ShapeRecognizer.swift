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

struct ShapeRecognizer {

    // MARK: - Dwell Detection

    /// Check if the user held the pencil still at the end of the stroke.
    /// Returns true if the last 400ms+ of the stroke shows < 5pt of movement.
    static func detectDwell(in stroke: PKStroke, dwellDuration: TimeInterval = 0.4, maxMovement: CGFloat = 5.0) -> Bool {
        let path = stroke.path
        guard path.count >= 10 else { return false }

        let totalDuration = path[path.count - 1].timeOffset
        guard totalDuration > dwellDuration else { return false }

        let dwellStartTime = totalDuration - dwellDuration
        let lastPoint = path[path.count - 1].location

        // Check all points after dwellStartTime — they should all be within maxMovement of the last point
        for i in stride(from: path.count - 1, through: 0, by: -1) {
            let pt = path[i]
            if pt.timeOffset < dwellStartTime { break }
            let dist = hypot(pt.location.x - lastPoint.x, pt.location.y - lastPoint.y)
            if dist > maxMovement { return false }
        }

        return true
    }

    // MARK: - Shape Recognition (only called after dwell confirmed)

    static func recognize(stroke: PKStroke) -> RecognizedShape {
        let rawPoints = extractPoints(from: stroke)
        guard rawPoints.count >= 5 else { return .none }
        let totalLength = polylineLength(rawPoints)
        guard totalLength >= 20 else { return .none }

        // Trim the dwell tail — remove points from the end that are part of the hold
        let trimmedPoints = trimDwellTail(rawPoints, stroke: stroke, dwellDuration: 0.4)
        guard trimmedPoints.count >= 3 else { return .none }

        let isClosed = isStrokeClosed(trimmedPoints, totalLength: polylineLength(trimmedPoints))

        // Try detection in order
        if !isClosed {
            if let line = tryLine(trimmedPoints) { return line }
            if let arrow = tryArrow(trimmedPoints) { return arrow }
        }

        if isClosed {
            if let circle = tryCircle(trimmedPoints) { return circle }
            if let rect = tryRectangle(trimmedPoints) { return rect }
            if let tri = tryTriangle(trimmedPoints) { return tri }
        }

        return .none
    }

    // MARK: - Trim Dwell Tail

    private static func trimDwellTail(_ points: [CGPoint], stroke: PKStroke, dwellDuration: TimeInterval) -> [CGPoint] {
        let path = stroke.path
        let totalDuration = path[path.count - 1].timeOffset
        let dwellStartTime = totalDuration - dwellDuration

        var trimmedCount = points.count
        for i in stride(from: path.count - 1, through: 0, by: -1) {
            if path[i].timeOffset < dwellStartTime { break }
            trimmedCount = i
        }

        return Array(points.prefix(max(3, trimmedCount)))
    }

    // MARK: - Closed Detection

    private static func isStrokeClosed(_ points: [CGPoint], totalLength: CGFloat) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        let closeDist = hypot(first.x - last.x, first.y - last.y)
        return closeDist < totalLength * 0.15
    }

    // MARK: - Line Detection

    private static func tryLine(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 2 else { return nil }
        let start = points.first!
        let end = points.last!
        let startEndDist = hypot(end.x - start.x, end.y - start.y)
        guard startEndDist > 10 else { return nil }

        let pathLen = polylineLength(points)
        // Path should not be much longer than straight-line distance
        guard pathLen / startEndDist < 1.3 else { return nil }

        // Max perpendicular deviation should be small relative to length
        var maxDev: CGFloat = 0
        for point in points {
            let dev = perpendicularDistance(point: point, lineStart: start, lineEnd: end)
            maxDev = max(maxDev, dev)
        }
        guard maxDev / startEndDist < 0.12 else { return nil }

        return .line(start: start, end: end)
    }

    // MARK: - Arrow Detection

    private static func tryArrow(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 10 else { return nil }

        // Check if main body (first 70%) is line-like
        let splitIdx = Int(Double(points.count) * 0.7)
        let bodyPoints = Array(points[0..<splitIdx])
        guard tryLine(bodyPoints) != nil else { return nil }

        // Check for V-shaped head in the last 30%
        let headPoints = Array(points[splitIdx...])
        guard headPoints.count >= 3 else { return nil }

        // The head should have at least one sharp direction reversal
        var hasReversal = false
        for i in 1..<headPoints.count - 1 {
            let v1 = CGPoint(x: headPoints[i].x - headPoints[i-1].x, y: headPoints[i].y - headPoints[i-1].y)
            let v2 = CGPoint(x: headPoints[i+1].x - headPoints[i].x, y: headPoints[i+1].y - headPoints[i].y)
            let dot = v1.x * v2.x + v1.y * v2.y
            let mag1 = hypot(v1.x, v1.y)
            let mag2 = hypot(v2.x, v2.y)
            guard mag1 > 0, mag2 > 0 else { continue }
            let cosAngle = dot / (mag1 * mag2)
            if cosAngle < -0.3 { // > ~107 degrees
                hasReversal = true
                break
            }
        }
        guard hasReversal else { return nil }

        let start = points.first!
        let end = bodyPoints.last!
        let dir = CGPoint(x: end.x - start.x, y: end.y - start.y)
        return .arrow(start: start, end: end, headAngle: atan2(dir.y, dir.x))
    }

    // MARK: - Circle Detection

    private static func tryCircle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 8 else { return nil }

        let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)

        let distances = points.map { hypot($0.x - cx, $0.y - cy) }
        let meanR = distances.reduce(0, +) / CGFloat(distances.count)
        guard meanR > 5 else { return nil }

        let variance = distances.map { pow($0 - meanR, 2) }.reduce(0, +) / CGFloat(distances.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / meanR

        // Coefficient of variation < 0.2 means points are roughly equidistant from center
        guard cv < 0.20 else { return nil }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let radiusX = (xs.max()! - xs.min()!) / 2.0
        let radiusY = (ys.max()! - ys.min()!) / 2.0
        let centroid = CGPoint(x: cx, y: cy)

        return .circle(center: centroid, radiusX: radiusX, radiusY: radiusY)
    }

    // MARK: - Rectangle Detection

    private static func tryRectangle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 8 else { return nil }

        let corners = findCorners(points, targetCount: 4)
        guard corners.count == 4 else { return nil }

        let pts = corners.map { points[$0] }

        // Check all 4 angles are roughly 90 degrees
        for i in 0..<4 {
            let prev = pts[(i + 3) % 4]
            let curr = pts[i]
            let next = pts[(i + 1) % 4]
            let v1 = CGPoint(x: curr.x - prev.x, y: curr.y - prev.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let dot = v1.x * v2.x + v1.y * v2.y
            let mag = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
            guard mag > 0 else { return nil }
            let angle = acos(max(-1, min(1, dot / mag))) * 180 / .pi
            guard abs(angle - 90) < 35 else { return nil }
        }

        let minX = pts.map(\.x).min()!
        let minY = pts.map(\.y).min()!
        let maxX = pts.map(\.x).max()!
        let maxY = pts.map(\.y).max()!
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let angle = atan2(pts[1].y - pts[0].y, pts[1].x - pts[0].x)

        return .rectangle(rect, angle: angle)
    }

    // MARK: - Triangle Detection

    private static func tryTriangle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 6 else { return nil }

        let corners = findCorners(points, targetCount: 3)
        guard corners.count == 3 else { return nil }

        let a = points[corners[0]]
        let b = points[corners[1]]
        let c = points[corners[2]]

        // Verify angles sum to roughly 180
        let angleA = interiorAngle(vertex: a, p1: b, p2: c)
        let angleB = interiorAngle(vertex: b, p1: a, p2: c)
        let angleC = interiorAngle(vertex: c, p1: a, p2: b)
        let sumDeg = (angleA + angleB + angleC) * 180 / .pi
        guard abs(sumDeg - 180) < 40 else { return nil }

        return .triangle(a, b, c)
    }

    // MARK: - Build Clean Stroke

    static func buildStroke(for shape: RecognizedShape, template: PKStroke) -> PKStroke? {
        let ink = template.ink
        let transform = CGAffineTransform.identity

        // Compute average stroke properties from template
        var forceSum: CGFloat = 0, sizeWSum: CGFloat = 0, sizeHSum: CGFloat = 0
        let count = template.path.count
        guard count > 0 else { return nil }
        for i in 0..<count {
            forceSum += template.path[i].force
            sizeWSum += template.path[i].size.width
            sizeHSum += template.path[i].size.height
        }
        let avgForce = max(forceSum / CGFloat(count), 1.0)
        let avgSize = CGSize(width: max(sizeWSum / CGFloat(count), 2), height: max(sizeHSum / CGFloat(count), 2))

        let geometryPoints: [CGPoint]
        switch shape {
        case .line(let start, let end):
            geometryPoints = [start, end]
        case .rectangle(let rect, _):
            geometryPoints = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY)
            ]
        case .circle(let center, let rx, let ry):
            geometryPoints = (0...36).map { i in
                let angle = CGFloat(i) / 36.0 * 2.0 * .pi
                return CGPoint(x: center.x + rx * cos(angle), y: center.y + ry * sin(angle))
            }
        case .triangle(let a, let b, let c):
            geometryPoints = [a, b, c, a]
        case .arrow(let start, let end, _):
            let dx = end.x - start.x, dy = end.y - start.y
            let len = hypot(dx, dy)
            guard len > 0 else { return nil }
            let headLen = min(len * 0.2, 30)
            let ux = dx / len, uy = dy / len
            let px = -uy, py = ux // perpendicular
            let tip = end
            let wing1 = CGPoint(x: tip.x - headLen * ux + headLen * 0.4 * px,
                               y: tip.y - headLen * uy + headLen * 0.4 * py)
            let wing2 = CGPoint(x: tip.x - headLen * ux - headLen * 0.4 * px,
                               y: tip.y - headLen * uy - headLen * 0.4 * py)
            geometryPoints = [start, tip, wing1, tip, wing2]
        case .none:
            return nil
        }

        guard geometryPoints.count >= 2 else { return nil }

        let strokePoints = geometryPoints.enumerated().map { idx, location in
            PKStrokePoint(
                location: location,
                timeOffset: Double(idx) / Double(max(geometryPoints.count - 1, 1)),
                size: avgSize,
                opacity: 1,
                force: avgForce,
                azimuth: 0,
                altitude: .pi / 4
            )
        }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: ink, path: path, transform: transform, mask: template.mask)
    }

    // MARK: - Geometry Helpers

    static func extractPoints(from stroke: PKStroke) -> [CGPoint] {
        (0..<stroke.path.count).map { stroke.path[$0].location }
    }

    static func polylineLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let len = hypot(dx, dy)
        guard len > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }
        return abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x) / len
    }

    private static func interiorAngle(vertex: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - vertex.x, y: p1.y - vertex.y)
        let v2 = CGPoint(x: p2.x - vertex.x, y: p2.y - vertex.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard mag > 0 else { return 0 }
        return acos(max(-1, min(1, dot / mag)))
    }

    private static func findCorners(_ points: [CGPoint], targetCount: Int) -> [Int] {
        guard points.count > targetCount * 3 else { return [] }
        let step = max(1, points.count / (targetCount * 4))

        var candidates: [(index: Int, angle: CGFloat)] = []
        for i in step..<points.count - step {
            let v1 = CGPoint(x: points[i].x - points[i - step].x, y: points[i].y - points[i - step].y)
            let v2 = CGPoint(x: points[i + step].x - points[i].x, y: points[i + step].y - points[i].y)
            let dot = v1.x * v2.x + v1.y * v2.y
            let mag = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
            guard mag > 0 else { continue }
            let cosAngle = dot / mag
            let angle = acos(max(-1, min(1, cosAngle)))
            if angle > .pi / 6 { // > 30 degrees
                candidates.append((i, angle))
            }
        }

        candidates.sort { $0.angle > $1.angle }

        // Non-maximum suppression: keep corners that are far enough apart
        let minDist = points.count / (targetCount * 2)
        var selected: [Int] = []
        for c in candidates {
            if selected.allSatisfy({ abs($0 - c.index) > minDist }) {
                selected.append(c.index)
            }
            if selected.count == targetCount { break }
        }

        return selected.sorted()
    }
}
