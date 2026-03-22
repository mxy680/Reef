import Foundation

struct CourseDTO: Codable {
    let id: String
    let userId: String
    let name: String
    let emoji: String
    let color: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case emoji
        case color
        case createdAt = "created_at"
    }

    func toDomain() -> Course {
        Course(id: id, userId: userId, name: name, emoji: emoji, color: color, createdAt: createdAt)
    }
}
