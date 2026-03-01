import Foundation
import Supabase

struct Profile: Codable {
    let id: String
    var displayName: String?
    var email: String?
    var grade: String?
    var subjects: [String]
    var onboardingCompleted: Bool
    var referralSource: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case grade
        case subjects
        case onboardingCompleted = "onboarding_completed"
        case referralSource = "referral_source"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

final class ProfileManager: Sendable {

    func fetchProfile() async -> Profile? {
        do {
            let session = try await supabase.auth.session
            let response: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            return response
        } catch {
            // PGRST116 = no rows found — expected for new users
            return nil
        }
    }

    func upsertProfile(fields: [String: AnyJSON]) async throws {
        let session = try await supabase.auth.session
        var payload = fields
        payload["id"] = .string(session.user.id.uuidString)

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }
}
