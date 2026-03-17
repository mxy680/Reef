import Foundation

struct PartRegionDTO: Codable, Hashable {
    let label: String?
    let page: Int
    let yStart: Double
    let yEnd: Double

    enum CodingKeys: String, CodingKey {
        case label, page
        case yStart = "y_start"
        case yEnd = "y_end"
    }

    func toDomain() -> PartRegion {
        PartRegion(label: label, page: page, yStart: yStart, yEnd: yEnd)
    }
}

struct QuestionRegionDataDTO: Codable, Hashable {
    let pageHeights: [Double]
    let regions: [PartRegionDTO]

    enum CodingKeys: String, CodingKey {
        case pageHeights = "page_heights"
        case regions
    }

    func toDomain() -> QuestionRegionData {
        QuestionRegionData(pageHeights: pageHeights, regions: regions.map { $0.toDomain() })
    }
}

struct DocumentDTO: Codable {
    let id: String
    let userId: String
    let filename: String
    let status: String
    let pageCount: Int?
    let problemCount: Int?
    let questionPages: [[Int]]?
    let questionRegions: [QuestionRegionDataDTO?]?
    let errorMessage: String?
    let statusMessage: String?
    let costCents: Int?
    let courseId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case filename
        case status
        case pageCount = "page_count"
        case problemCount = "problem_count"
        case questionPages = "question_pages"
        case questionRegions = "question_regions"
        case errorMessage = "error_message"
        case statusMessage = "status_message"
        case costCents = "cost_cents"
        case courseId = "course_id"
        case createdAt = "created_at"
    }

    func toDomain() -> Document {
        let docStatus = DocumentStatus(rawValue: status) ?? {
            print("[DocumentDTO] Unknown status '\(status)' for document \(id), defaulting to .processing")
            return .processing
        }()
        return Document(
            id: id,
            userId: userId,
            filename: filename,
            status: docStatus,
            pageCount: pageCount,
            problemCount: problemCount,
            questionPages: questionPages,
            questionRegions: questionRegions?.map { $0?.toDomain() },
            errorMessage: errorMessage,
            statusMessage: statusMessage,
            costCents: costCents,
            courseId: courseId,
            createdAt: createdAt
        )
    }
}
