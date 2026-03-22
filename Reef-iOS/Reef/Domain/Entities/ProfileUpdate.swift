import Foundation

struct ProfileUpdate: Sendable {
    var displayName: String?
    var email: String?
    var grade: String?
    var subjects: [String]?
    var referralSource: String?
    var major: String?
    var studyGoal: String?
    var painPoints: [String]?
    var learningStyle: String?
    var favoriteTopic: String?
    var onboardingCompleted: Bool?
    var settings: UserSettings?
}
