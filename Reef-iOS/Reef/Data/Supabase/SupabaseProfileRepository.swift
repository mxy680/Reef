import Foundation
import Supabase

struct SupabaseProfileRepository: ProfileRepository {
    func fetchProfile() async throws -> Profile? {
        let session = try await supabase.auth.session
        do {
            let dto: ProfileDTO = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            return dto.toDomain()
        } catch let error as PostgrestError where error.code == "PGRST116" {
            // No rows found — expected for new users
            return nil
        }
        // All other errors (network, auth, server) propagate to caller
    }

    func upsertProfile(_ update: ProfileUpdate) async throws {
        let session = try await supabase.auth.session
        var payload: [String: AnyJSON] = ["id": .string(session.user.id.uuidString)]

        if let v = update.displayName { payload["display_name"] = .string(v) }
        if let v = update.email { payload["email"] = .string(v) }
        if let v = update.grade { payload["grade"] = .string(v) }
        if let v = update.subjects { payload["subjects"] = .array(v.map { .string($0) }) }
        if let v = update.referralSource { payload["referral_source"] = .string(v) }
        if let v = update.onboardingCompleted { payload["onboarding_completed"] = .bool(v) }

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }
}
