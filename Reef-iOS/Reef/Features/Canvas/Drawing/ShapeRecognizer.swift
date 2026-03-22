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

    // MARK: - Remote Shape Recognition

    struct FitShapeResponse: Decodable {
        let shape: String
        let confidence: Double
        let geometry: FitShapeGeometry
    }

    struct FitShapeGeometry: Decodable {
        let start: [CGFloat]?
        let end: [CGFloat]?
        let x: CGFloat?
        let y: CGFloat?
        let width: CGFloat?
        let height: CGFloat?
        let angle: CGFloat?
        let center: [CGFloat]?
        let radius_x: CGFloat?
        let radius_y: CGFloat?
        let vertices: [[CGFloat]]?
        let head_angle: CGFloat?
    }

    static func recognizeRemote(stroke: PKStroke) async -> RecognizedShape {
        guard stroke.path.count >= 5 else { return .none }
        let rawPoints = extractPoints(from: stroke)
        let totalLength = polylineLength(rawPoints)
        guard totalLength >= 20 else { return .none }

        let pointArrays: [[CGFloat]] = rawPoints.map { [$0.x, $0.y] }
        let isClosed = distance(rawPoints.first!, rawPoints.last!) < totalLength * 0.15

        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/fit-shape") else {
            print("[ShapeRecognizer] No REEF_SERVER_URL configured")
            return .none
        }

        do {
            struct RequestBody: Encodable {
                let points: [[CGFloat]]
                let closed: Bool
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 3
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(RequestBody(points: pointArrays, closed: isClosed))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("[ShapeRecognizer] Server returned non-2xx")
                return .none
            }

            let fitResponse = try JSONDecoder().decode(FitShapeResponse.self, from: data)
            print("[ShapeRecognizer] remote: shape=\(fitResponse.shape) confidence=\(String(format: "%.2f", fitResponse.confidence))")

            guard fitResponse.shape != "none" else { return .none }
            return mapResponse(fitResponse)
        } catch {
            print("[ShapeRecognizer] remote failed: \(error)")
            return .none
        }
    }

    private static func mapResponse(_ response: FitShapeResponse) -> RecognizedShape {
        let geo = response.geometry
        switch response.shape {
        case "line":
            guard let s = geo.start, let e = geo.end, s.count >= 2, e.count >= 2 else { return .none }
            return .line(start: CGPoint(x: s[0], y: s[1]), end: CGPoint(x: e[0], y: e[1]))
        case "rectangle":
            guard let x = geo.x, let y = geo.y, let w = geo.width, let h = geo.height else { return .none }
            return .rectangle(CGRect(x: x, y: y, width: w, height: h), angle: geo.angle ?? 0)
        case "circle":
            guard let c = geo.center, c.count >= 2, let rx = geo.radius_x, let ry = geo.radius_y else { return .none }
            return .circle(center: CGPoint(x: c[0], y: c[1]), radiusX: rx, radiusY: ry)
        case "triangle":
            guard let verts = geo.vertices, verts.count >= 3 else { return .none }
            return .triangle(
                CGPoint(x: verts[0][0], y: verts[0][1]),
                CGPoint(x: verts[1][0], y: verts[1][1]),
                CGPoint(x: verts[2][0], y: verts[2][1])
            )
        case "arrow":
            guard let s = geo.start, let e = geo.end, s.count >= 2, e.count >= 2 else { return .none }
            return .arrow(start: CGPoint(x: s[0], y: s[1]), end: CGPoint(x: e[0], y: e[1]), headAngle: geo.head_angle ?? 0)
        default:
            return .none
        }
    }

    // MARK: - Build Clean Stroke

    static func buildStroke(for shape: RecognizedShape, template: PKStroke) -> PKStroke? {
        let ink = template.ink
        let transform = CGAffineTransform.identity

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
            geometryPoints = interpolateEdge(from: start, to: end, count: 10)
        case .rectangle(let rect, _):
            let tl = CGPoint(x: rect.minX, y: rect.minY)
            let tr = CGPoint(x: rect.maxX, y: rect.minY)
            let br = CGPoint(x: rect.maxX, y: rect.maxY)
            let bl = CGPoint(x: rect.minX, y: rect.maxY)
            geometryPoints = interpolateEdge(from: tl, to: tr, count: 8)
                + interpolateEdge(from: tr, to: br, count: 8).dropFirst()
                + interpolateEdge(from: br, to: bl, count: 8).dropFirst()
                + interpolateEdge(from: bl, to: tl, count: 8).dropFirst()
        case .circle(let center, let rx, let ry):
            geometryPoints = (0...64).map { i in
                let angle = CGFloat(i) / 64.0 * 2.0 * .pi
                return CGPoint(x: center.x + rx * cos(angle), y: center.y + ry * sin(angle))
            }
        case .triangle(let a, let b, let c):
            geometryPoints = interpolateEdge(from: a, to: b, count: 8)
                + interpolateEdge(from: b, to: c, count: 8).dropFirst()
                + interpolateEdge(from: c, to: a, count: 8).dropFirst()
        case .arrow(let start, let end, _):
            let dx = end.x - start.x, dy = end.y - start.y
            let len = hypot(dx, dy)
            guard len > 0 else { return nil }
            let headLen = min(len * 0.2, 30)
            let ux = dx / len, uy = dy / len
            let px = -uy, py = ux
            let tip = end
            let wing1 = CGPoint(x: tip.x - headLen * ux + headLen * 0.4 * px,
                               y: tip.y - headLen * uy + headLen * 0.4 * py)
            let wing2 = CGPoint(x: tip.x - headLen * ux - headLen * 0.4 * px,
                               y: tip.y - headLen * uy - headLen * 0.4 * py)
            geometryPoints = interpolateEdge(from: start, to: tip, count: 10)
                + interpolateEdge(from: tip, to: wing1, count: 4).dropFirst()
                + interpolateEdge(from: wing1, to: tip, count: 4).dropFirst()
                + interpolateEdge(from: tip, to: wing2, count: 4).dropFirst()
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

    // MARK: - Helpers

    private static func interpolateEdge(from a: CGPoint, to b: CGPoint, count: Int) -> [CGPoint] {
        guard count >= 2 else { return [a, b] }
        return (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
        }
    }

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
}
