import Foundation

enum DocumentStatus: String, Codable {
    case processing
    case completed
    case failed
}

struct Document: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let filename: String
    let status: DocumentStatus
    let pageCount: Int?
    let problemCount: Int?
    let errorMessage: String?
    let courseId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case filename
        case status
        case pageCount = "page_count"
        case problemCount = "problem_count"
        case errorMessage = "error_message"
        case courseId = "course_id"
        case createdAt = "created_at"
    }

    var displayName: String {
        filename.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
    }

    var statusLabel: String {
        switch status {
        case .processing:
            return "Processing..."
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
                let date = ISO8601DateFormatter().date(from: createdAt) ?? Date()
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
            return parts.joined(separator: " · ")
        }
    }
}
