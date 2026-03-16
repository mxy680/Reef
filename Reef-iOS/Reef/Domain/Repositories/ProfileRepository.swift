import Foundation

protocol ProfileRepository: Sendable {
    func fetchProfile() async -> Profile?
    func upsertProfile(fields: [String: Any]) async throws
}
