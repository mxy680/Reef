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

    static func recognize(stroke: PKStroke) -> RecognizedShape {
        guard stroke.path.count >= 5 else { return .none }

        let rawPoints = extractPoints(from: stroke)
        let totalLength = polylineLength(rawPoints)
        guard totalLength >= 20 else { return .none }

        let reversals = countDirectionReversals(rawPoints)
        guard reversals <= 8 else { return .none }

        let points = resamplePoints(rawPoints, count: 50)

        if let line = tryLine(points) { return line }
        if let arrow = tryArrow(points) { return arrow }
        if let triangle = tryTriangle(points) { return triangle }
        if let rect = tryRectangle(points) { return rect }
        if let circle = tryCircle(points) { return circle }

        return .none
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

    // MARK: - Detection Helpers

    private static func tryLine(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 2 else { return nil }
        let start = points.first!
        let end = points.last!
        let startEndDist = distance(start, end)
        guard startEndDist > 0 else { return nil }
        let strokeLen = polylineLength(points)

        let maxDev = maxPerpendicularDeviation(points: points, lineStart: start, lineEnd: end)

        if maxDev / strokeLen < 0.06 && strokeLen / startEndDist < 1.15 {
            return .line(start: start, end: end)
        }
        return nil
    }

    private static func tryArrow(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 8 else { return nil }
        let splitIndex = Int(Double(points.count) * 0.75)
        let headPoints = Array(points[splitIndex...])
        let bodyPoints = Array(points[...splitIndex])

        // Body must be line-like
        guard let bodyLine = tryLine(bodyPoints) else { return nil }
        guard case .line(let start, _) = bodyLine else { return nil }

        // Tail must have a sharp direction change
        guard headPoints.count >= 3 else { return nil }
        var directionChanges = 0
        for i in 1..<headPoints.count - 1 {
            let v1 = CGPoint(x: headPoints[i].x - headPoints[i-1].x,
                             y: headPoints[i].y - headPoints[i-1].y)
            let v2 = CGPoint(x: headPoints[i+1].x - headPoints[i].x,
                             y: headPoints[i+1].y - headPoints[i].y)
            let angle = abs(angleBetween(v1, v2))
            if angle > (CGFloat.pi * 30.0 / 180.0) {
                directionChanges += 1
            }
        }
        guard directionChanges >= 2 else { return nil }

        let end = bodyPoints.last!
        let dir = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let headAngle = atan2(dir.y, dir.x)

        return .arrow(start: start, end: end, headAngle: headAngle)
    }

    private static func tryTriangle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 4 else { return nil }
        guard isClosed(points, threshold: 0.08) else { return nil }

        let corners = findCorners(points: points, count: 3)
        guard corners.count == 3 else { return nil }
        let a = points[corners[0]]
        let b = points[corners[1]]
        let c = points[corners[2]]

        let angleA = interiorAngle(vertex: a, p1: b, p2: c)
        let angleB = interiorAngle(vertex: b, p1: a, p2: c)
        let angleC = interiorAngle(vertex: c, p1: a, p2: b)
        let sumDeg = (angleA + angleB + angleC) * 180.0 / CGFloat.pi
        guard abs(sumDeg - 180.0) < 30.0 else { return nil }

        // Verify segments are roughly straight
        let segments = [(0, corners[0]), (corners[0], corners[1]), (corners[1], corners[2]), (corners[2], points.count - 1)]
        for (start, end) in segments {
            if end <= start { continue }
            let seg = Array(points[start...end])
            guard seg.count >= 2 else { continue }
            let s = seg.first!
            let e = seg.last!
            let segLen = polylineLength(seg)
            let dev = maxPerpendicularDeviation(points: seg, lineStart: s, lineEnd: e)
            guard segLen > 0, dev / segLen < 0.15 else { return nil }
        }

        return .triangle(a, b, c)
    }

    private static func tryRectangle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 5 else { return nil }
        guard isClosed(points, threshold: 0.08) else { return nil }

        let corners = findCorners(points: points, count: 4)
        guard corners.count == 4 else { return nil }

        let pts = corners.map { points[$0] }
        for i in 0..<4 {
            let prev = pts[(i + 3) % 4]
            let curr = pts[i]
            let next = pts[(i + 1) % 4]
            let v1 = CGPoint(x: curr.x - prev.x, y: curr.y - prev.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let angle = abs(angleBetween(v1, v2)) * 180.0 / CGFloat.pi
            guard abs(angle - 90.0) < 25.0 else { return nil }
        }

        // Verify opposite sides roughly equal
        let s0 = distance(pts[0], pts[1])
        let s1 = distance(pts[1], pts[2])
        let s2 = distance(pts[2], pts[3])
        let s3 = distance(pts[3], pts[0])
        guard s0 > 0, s1 > 0, s2 > 0, s3 > 0 else { return nil }
        let ratio02 = min(s0, s2) / max(s0, s2)
        let ratio13 = min(s1, s3) / max(s1, s3)
        guard ratio02 >= 0.6 && ratio13 >= 0.6 else { return nil }

        // Compute bounding rect from corners and angle
        let minX = pts.map { $0.x }.min()!
        let minY = pts.map { $0.y }.min()!
        let maxX = pts.map { $0.x }.max()!
        let maxY = pts.map { $0.y }.max()!
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Compute angle from first edge
        let dx = pts[1].x - pts[0].x
        let dy = pts[1].y - pts[0].y
        let angle = atan2(dy, dx)

        return .rectangle(rect, angle: angle)
    }

    private static func tryCircle(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 5 else { return nil }
        guard isClosed(points, threshold: 0.10) else { return nil }

        let centroid = computeCentroid(points)
        let distances = points.map { distance($0, centroid) }
        let mean = distances.reduce(0, +) / CGFloat(distances.count)
        guard mean > 0 else { return nil }

        let variance = distances.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(distances.count)
        let stdDev = sqrt(variance)

        guard stdDev / mean < 0.15 else { return nil }

        // Compute radii as bounding extents from centroid
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        let radiusX = (xs.max()! - xs.min()!) / 2.0
        let radiusY = (ys.max()! - ys.min()!) / 2.0

        return .circle(center: centroid, radiusX: radiusX, radiusY: radiusY)
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

    static func countDirectionReversals(_ points: [CGPoint]) -> Int {
        guard points.count >= 3 else { return 0 }
        var reversals = 0
        for i in 1..<points.count - 1 {
            let v1 = CGPoint(x: points[i].x - points[i-1].x,
                             y: points[i].y - points[i-1].y)
            let v2 = CGPoint(x: points[i+1].x - points[i].x,
                             y: points[i+1].y - points[i].y)
            let dot = v1.x * v2.x + v1.y * v2.y
            if dot < 0 { reversals += 1 }
        }
        return reversals
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

    private static func maxPerpendicularDeviation(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        points.map { perpendicularDistance(point: $0, lineStart: lineStart, lineEnd: lineEnd) }.max() ?? 0
    }

    private static func isClosed(_ points: [CGPoint], threshold: CGFloat) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        let perim = polylineLength(points)
        guard perim > 0 else { return false }
        return distance(first, last) / perim < threshold
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

    /// Finds `count` corner indices by finding points with highest cumulative angle change
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
