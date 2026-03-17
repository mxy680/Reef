import Foundation

enum DocumentStatus: String, Sendable {
    case processing
    case completed
    case failed
}

struct PartRegion: Sendable, Hashable {
    let label: String?
    let page: Int
    let yStart: Double
    let yEnd: Double
}

struct QuestionRegionData: Sendable, Hashable {
    let pageHeights: [Double]
    let regions: [PartRegion]
}

struct Document: Identifiable, Sendable, Hashable {
    let id: String
    let userId: String
    let filename: String
    let status: DocumentStatus
    let pageCount: Int?
    let problemCount: Int?
    let questionPages: [[Int]]?
    let questionRegions: [QuestionRegionData?]?
    let errorMessage: String?
    let statusMessage: String?
    let costCents: Int?
    let courseId: String?
    let createdAt: String

    var displayName: String {
        filename.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
    }

    private static nonisolated(unsafe) let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var statusLabel: String {
        switch status {
        case .processing:
            return statusMessage ?? "Processing..."
        case .failed:
            return "Failed"
        case .completed:
            var parts: [String] = []
            if let pages = pageCount {
                parts.append("\(pages) \(pages == 1 ? "page" : "pages")")
            }
            if let problems = problemCount {
                parts.append("\(problems) \(problems == 1 ? "problem" : "problems")")
            }
            if parts.isEmpty {
                let date = Self.iso8601Formatter.date(from: createdAt) ?? Date()
                return Self.dateFormatter.string(from: date)
            }
            return parts.joined(separator: " · ")
        }
    }
}
