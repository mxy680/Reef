import Foundation

// MARK: - $1 Unistroke Recognizer
//
// Based on: Wobbrock, J.O., Wilson, A.D., Li, Y. (2007). Gestures without libraries,
// toolkits or training: A $1 recognizer for user interface prototypes.
// UIST 2007 Proceedings. https://depts.washington.edu/acelab/proj/dollar/index.html
//
// MIT License — original algorithm by the University of Washington ACE Lab.

// MARK: - Public Types

struct UnistrokeTemplate {
    let name: String
    let points: [CGPoint]
}

struct UnistrokeResult {
    let name: String
    let score: Double  // 0.0 – 1.0
}

// MARK: - Private Types

private struct ProcessedTemplate {
    let name: String
    let points: [CGPoint]
}

// MARK: - Recognizer

struct UnistrokeRecognizer {
    private let templates: [ProcessedTemplate]
    private let numPoints: Int
    private let squareSize: CGFloat

    init(templates: [UnistrokeTemplate], numPoints: Int = 64, squareSize: CGFloat = 250) {
        self.numPoints = numPoints
        self.squareSize = squareSize
        self.templates = templates.map {
            ProcessedTemplate(
                name: $0.name,
                points: Self.process($0.points, numPoints: numPoints, squareSize: squareSize)
            )
        }
    }

    func recognize(_ points: [CGPoint]) -> UnistrokeResult? {
        guard points.count >= 2 else { return nil }
        let processed = Self.process(points, numPoints: numPoints, squareSize: squareSize)

        var bestScore: Double = 0
        var bestName: String = ""

        let diagonal = 0.5 * Double(sqrt(squareSize * squareSize + squareSize * squareSize))

        for template in templates {
            let d = Self.distanceAtBestAngle(
                processed,
                template.points,
                -.pi / 4,
                .pi / 4,
                .pi / 90
            )
            let score = 1.0 - Double(d) / diagonal
            if score > bestScore {
                bestScore = score
                bestName = template.name
            }
        }

        guard !bestName.isEmpty else { return nil }
        return UnistrokeResult(name: bestName, score: bestScore)
    }
}

// MARK: - Pipeline

extension UnistrokeRecognizer {

    /// Full $1 processing pipeline: resample → rotate → scale → translate.
    static func process(_ points: [CGPoint], numPoints: Int, squareSize: CGFloat) -> [CGPoint] {
        var pts = resample(points, n: numPoints)
        let angle = indicativeAngle(pts)
        pts = rotateBy(pts, radians: -angle)
        pts = scaleTo(pts, size: squareSize)
        pts = translateTo(pts, origin: .zero)
        return pts
    }
}

// MARK: - Algorithm Steps

extension UnistrokeRecognizer {

    /// Resample a path to exactly `n` evenly-spaced points.
    /// Follows the canonical $1 resample algorithm: walk the polyline and emit
    /// an interpolated point each time the accumulated distance crosses `interval`.
    static func resample(_ points: [CGPoint], n: Int) -> [CGPoint] {
        guard points.count >= 2, n >= 2 else { return points }
        let totalLen = pathLength(points)
        guard totalLen > 0 else { return points }
        let interval = totalLen / CGFloat(n - 1)

        var result: [CGPoint] = [points[0]]
        // Work on a mutable copy so we can prepend interpolated points back in.
        var pts = points
        var accumulated: CGFloat = 0

        var i = 1
        while i < pts.count {
            let d = distance(pts[i - 1], pts[i])
            if accumulated + d >= interval {
                let t = (interval - accumulated) / d
                let q = CGPoint(
                    x: pts[i - 1].x + t * (pts[i].x - pts[i - 1].x),
                    y: pts[i - 1].y + t * (pts[i].y - pts[i - 1].y)
                )
                result.append(q)
                // Insert q back so the next segment starts from q.
                pts.insert(q, at: i)
                accumulated = 0
            } else {
                accumulated += d
            }
            i += 1
        }

        // Floating-point drift may leave us one point short; pad with the last point.
        if result.count < n {
            result.append(pts.last!)
        }
        return Array(result.prefix(n))
    }

    /// Angle from the centroid to the first point (used as the indicative angle).
    static func indicativeAngle(_ points: [CGPoint]) -> CGFloat {
        let c = centroid(points)
        return atan2(c.y - points[0].y, c.x - points[0].x)
    }

    /// Rotate all points around their centroid by `radians`.
    static func rotateBy(_ points: [CGPoint], radians: CGFloat) -> [CGPoint] {
        let c = centroid(points)
        let cosA = cos(radians)
        let sinA = sin(radians)
        return points.map { p in
            let dx = p.x - c.x
            let dy = p.y - c.y
            return CGPoint(
                x: c.x + dx * cosA - dy * sinA,
                y: c.y + dx * sinA + dy * cosA
            )
        }
    }

    /// Scale points so their bounding box fits inside a `size × size` square,
    /// preserving aspect ratio for more robust matching.
    static func scaleTo(_ points: [CGPoint], size: CGFloat) -> [CGPoint] {
        let box = boundingBox(points)
        guard box.width > 0, box.height > 0 else { return points }
        return points.map { p in
            CGPoint(
                x: p.x * (size / box.width),
                y: p.y * (size / box.height)
            )
        }
    }

    /// Translate points so their centroid sits at `origin`.
    static func translateTo(_ points: [CGPoint], origin: CGPoint) -> [CGPoint] {
        let c = centroid(points)
        return points.map { p in
            CGPoint(x: p.x + origin.x - c.x, y: p.y + origin.y - c.y)
        }
    }
}

// MARK: - Matching

extension UnistrokeRecognizer {

    /// Golden-section search for the rotation angle that minimises path distance.
    static func distanceAtBestAngle(
        _ points: [CGPoint],
        _ template: [CGPoint],
        _ a: CGFloat,
        _ b: CGFloat,
        _ threshold: CGFloat
    ) -> CGFloat {
        let phi: CGFloat = 0.5 * (-1.0 + sqrt(5.0))  // golden ratio
        var lower = a
        var upper = b
        var x1 = phi * lower + (1.0 - phi) * upper
        var f1 = distanceAtAngle(points, template, x1)
        var x2 = (1.0 - phi) * lower + phi * upper
        var f2 = distanceAtAngle(points, template, x2)

        while abs(upper - lower) > threshold {
            if f1 < f2 {
                upper = x2
                x2 = x1
                f2 = f1
                x1 = phi * lower + (1.0 - phi) * upper
                f1 = distanceAtAngle(points, template, x1)
            } else {
                lower = x1
                x1 = x2
                f1 = f2
                x2 = (1.0 - phi) * lower + phi * upper
                f2 = distanceAtAngle(points, template, x2)
            }
        }
        return min(f1, f2)
    }

    /// Rotate `points` by `radians` around their centroid and compute path distance to `template`.
    static func distanceAtAngle(
        _ points: [CGPoint],
        _ template: [CGPoint],
        _ radians: CGFloat
    ) -> CGFloat {
        let rotated = rotateBy(points, radians: radians)
        return pathDistance(rotated, template)
    }

    /// Average point-to-point distance between two equal-length paths.
    static func pathDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        guard !a.isEmpty, a.count == b.count else { return .infinity }
        var total: CGFloat = 0
        for i in 0..<a.count {
            total += distance(a[i], b[i])
        }
        return total / CGFloat(a.count)
    }
}

// MARK: - Geometric Utilities

extension UnistrokeRecognizer {

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var length: CGFloat = 0
        for i in 1..<points.count {
            length += distance(points[i - 1], points[i])
        }
        return length
    }

    static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let n = CGFloat(points.count)
        let sumX = points.reduce(CGFloat(0)) { $0 + $1.x }
        let sumY = points.reduce(CGFloat(0)) { $0 + $1.y }
        return CGPoint(x: sumX / n, y: sumY / n)
    }

    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        let minX = points.min(by: { $0.x < $1.x })!.x
        let minY = points.min(by: { $0.y < $1.y })!.y
        let maxX = points.max(by: { $0.x < $1.x })!.x
        let maxY = points.max(by: { $0.y < $1.y })!.y
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
