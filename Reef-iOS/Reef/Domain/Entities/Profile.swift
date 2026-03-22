import Foundation

struct Profile: Sendable {
    let id: String
    var displayName: String?
    var email: String?
    var grade: String?
    var subjects: [String]
    var onboardingCompleted: Bool
    var referralSource: String?
    var major: String?
    var studyGoal: String?
    var painPoints: [String]?
    var learningStyle: String?
    var favoriteTopic: String?
    var settings: UserSettings = UserSettings()
    var createdAt: String?
    var updatedAt: String?
}
