import SwiftUI

@Observable
@MainActor
final class CoursesViewModel {
    var courses: [Course] = []
    var isLoading = true
    var addCourseTarget: Bool = false
    var editCourseTarget: Course? = nil
    var deleteCourseTarget: Course? = nil
    var toastMessage: String?

    private let repo: CourseRepository

    init(repo: CourseRepository = SupabaseCourseRepository()) {
        self.repo = repo
    }

    // MARK: - Computed

    var maxCourses: Int? {
        let limit = TierLimits.current().maxCourses
        return limit == Int.max ? nil : limit
    }

    var atCourseLimit: Bool {
        guard let max = maxCourses else { return false }
        return courses.count >= max
    }

    // MARK: - Fetch

    func fetchCourses() async {
        do {
            courses = try await repo.listCourses()
        } catch {
            // Keep existing courses on failure; loading state clears regardless
        }
        isLoading = false
    }

    // MARK: - Create

    @discardableResult
    func createCourse(name: String, emoji: String, color: String) async -> Course? {
        do {
            let newCourse = try await repo.createCourse(name: name, emoji: emoji, color: color)
            courses.insert(newCourse, at: 0)
            return newCourse
        } catch {
            showToast("Failed to create course")
            return nil
        }
    }

    // MARK: - Update

    func updateCourse(id: String, name: String, emoji: String, color: String) async {
        do {
            try await repo.updateCourse(id: id, name: name, emoji: emoji, color: color)
            if let idx = courses.firstIndex(where: { $0.id == id }) {
                let existing = courses[idx]
                courses[idx] = Course(
                    id: existing.id,
                    userId: existing.userId,
                    name: name,
                    emoji: emoji,
                    color: color,
                    createdAt: existing.createdAt
                )
            }
        } catch {
            showToast("Failed to update course")
        }
    }

    // MARK: - Delete

    func deleteCourse(_ id: String) async {
        do {
            try await repo.deleteCourse(id: id)
            courses.removeAll { $0.id == id }
        } catch {
            showToast("Failed to delete course")
        }
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toastMessage == message {
                withAnimation { toastMessage = nil }
            }
        }
    }
}
