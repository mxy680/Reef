import Foundation

protocol ProfileRepository: Sendable {
    func fetchProfile() async throws -> Profile?
    func upsertProfile(_ update: ProfileUpdate) async throws
}
