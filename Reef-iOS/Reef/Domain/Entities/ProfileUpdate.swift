import Foundation

struct ProfileUpdate: Sendable {
    var displayName: String?
    var email: String?
    var grade: String?
    var subjects: [String]?
    var referralSource: String?
    var onboardingCompleted: Bool?
}
