import Foundation
import Supabase

struct SupabaseProfileRepository: ProfileRepository {
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
            return nil
        }
    }

    func upsertProfile(fields: [String: Any]) async throws {
        let session = try await supabase.auth.session
        var payload: [String: AnyJSON] = [:]
        payload["id"] = .string(session.user.id.uuidString)
        for (key, value) in fields {
            if let s = value as? String { payload[key] = .string(s) }
            else if let b = value as? Bool { payload[key] = .bool(b) }
            else if let arr = value as? [String] {
                payload[key] = .array(arr.map { .string($0) })
            }
        }
        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }
}
