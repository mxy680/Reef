import Foundation

protocol CourseRepository: Sendable {
    func listCourses() async throws -> [Course]
    func createCourse(name: String, emoji: String, color: String) async throws -> Course
    func updateCourse(id: String, name: String, emoji: String, color: String) async throws
    func deleteCourse(id: String) async throws
}
