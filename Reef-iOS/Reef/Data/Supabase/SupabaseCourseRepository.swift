import Foundation
@preconcurrency import Supabase

enum CourseRepositoryError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}

struct SupabaseCourseRepository: CourseRepository {

    private func getUserId() async throws -> String {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            throw CourseRepositoryError.notAuthenticated
        }
        return userId
    }

    // MARK: - List

    func listCourses() async throws -> [Course] {
        let userId = try await getUserId()
        let dtos: [CourseDTO] = try await supabase
            .from("courses")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    // MARK: - Create

    func createCourse(name: String, emoji: String, color: String) async throws -> Course {
        let userId = try await getUserId()

        struct InsertPayload: Encodable {
            let user_id: String
            let name: String
            let emoji: String
            let color: String
        }

        let dto: CourseDTO = try await supabase
            .from("courses")
            .insert(InsertPayload(user_id: userId, name: name, emoji: emoji, color: color))
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    // MARK: - Update

    func updateCourse(id: String, name: String, emoji: String, color: String) async throws {
        let userId = try await getUserId()
        let payload: [String: String] = [
            "name": name,
            "emoji": emoji,
            "color": color
        ]
        try await supabase
            .from("courses")
            .update(payload)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Delete

    func deleteCourse(id: String) async throws {
        let userId = try await getUserId()
        // Unassign documents from this course before deleting
        try await supabase
            .from("documents")
            .update(["course_id": AnyJSON.null])
            .eq("course_id", value: id)
            .eq("user_id", value: userId)
            .execute()

        try await supabase
            .from("courses")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }
}
