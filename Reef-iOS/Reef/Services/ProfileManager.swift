import Foundation
import Supabase

final class ProfileManager: Sendable {

    func fetchProfile() async -> Profile? {
        do {
            let session = try await supabase.auth.session
            let dto: ProfileDTO = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            return dto.toDomain()
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
