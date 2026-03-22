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
        if let v = update.major { payload["major"] = .string(v) }
        if let v = update.studyGoal { payload["study_goal"] = .string(v) }
        if let v = update.painPoints { payload["pain_points"] = .array(v.map { .string($0) }) }
        if let v = update.learningStyle { payload["learning_style"] = .string(v) }
        if let v = update.favoriteTopic { payload["favorite_topic"] = .string(v) }
        if let v = update.onboardingCompleted { payload["onboarding_completed"] = .bool(v) }
        if let settings = update.settings {
            payload["settings"] = try encodeToAnyJSON(settings)
        }

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }

    // MARK: - Helpers

    private func encodeToAnyJSON<T: Encodable>(_ value: T) throws -> AnyJSON {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return anyJSONFromObject(object)
    }

    private func anyJSONFromObject(_ object: Any) -> AnyJSON {
        switch object {
        case let dict as [String: Any]:
            return .object(dict.mapValues { anyJSONFromObject($0) })
        case let array as [Any]:
            return .array(array.map { anyJSONFromObject($0) })
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            // NSNumber wraps both Bool and numeric types
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return .bool(number.boolValue)
            }
            if number.doubleValue == Double(number.intValue) {
                return .integer(number.intValue)
            }
            return .double(number.doubleValue)
        case is NSNull:
            return .null
        default:
            return .null
        }
    }
}
