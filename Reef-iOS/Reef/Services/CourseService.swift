import Foundation
@preconcurrency import Supabase

enum CourseServiceError: LocalizedError {
    case notAuthenticated
    case limitReached(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .limitReached(let msg):
            return msg
        }
    }
}

actor CourseService {
    static let shared = CourseService()

    private func getUserId() async throws -> String {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            throw CourseServiceError.notAuthenticated
        }
        return userId
    }

    // MARK: - List

    func listCourses() async throws -> [Course] {
        let response: [Course] = try await supabase
            .from("courses")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    // MARK: - Create

    func createCourse(name: String, emoji: String = "📚", color: String = "") async throws -> Course {
        let userId = try await getUserId()

        // Check tier limit
        let existing: [Course] = try await supabase
            .from("courses")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        let limits = TierLimits.current()
        if existing.count >= limits.maxCourses {
            throw CourseServiceError.limitReached("Course limit reached — upgrade to add more")
        }

        struct InsertPayload: Encodable {
            let user_id: String
            let name: String
            let emoji: String
            let color: String
        }

        let newCourse: Course = try await supabase
            .from("courses")
            .insert(InsertPayload(user_id: userId, name: name, emoji: emoji, color: color))
            .select()
            .single()
            .execute()
            .value
        return newCourse
    }

    // MARK: - Update

    func updateCourse(_ courseId: String, name: String? = nil, emoji: String? = nil, color: String? = nil) async throws {
        var payload: [String: String] = [:]
        if let name { payload["name"] = name }
        if let emoji { payload["emoji"] = emoji }
        if let color { payload["color"] = color }
        guard !payload.isEmpty else { return }

        try await supabase
            .from("courses")
            .update(payload)
            .eq("id", value: courseId)
            .execute()
    }

    // MARK: - Delete

    func deleteCourse(_ courseId: String) async throws {
        try await supabase
            .from("courses")
            .delete()
            .eq("id", value: courseId)
            .execute()
    }

    // MARK: - Documents for Course

    func listDocumentsForCourse(_ courseId: String) async throws -> [Document] {
        let response: [Document] = try await supabase
            .from("documents")
            .select()
            .eq("course_id", value: courseId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
}
