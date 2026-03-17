import Foundation

struct Course: Identifiable, Sendable, Hashable {
    let id: String
    let userId: String
    let name: String
    let emoji: String
    let color: String
    let createdAt: String
}
