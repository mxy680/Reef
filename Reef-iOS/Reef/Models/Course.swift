import Foundation

struct Course: Identifiable, Codable, Hashable {
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

    // Convenience init for local creation (sidebar placeholders)
    init(id: String = UUID().uuidString, userId: String = "", name: String, emoji: String = "📚", color: String = "", createdAt: String = "") {
        self.id = id
        self.userId = userId
        self.name = name
        self.emoji = emoji
        self.color = color
        self.createdAt = createdAt
    }
}
