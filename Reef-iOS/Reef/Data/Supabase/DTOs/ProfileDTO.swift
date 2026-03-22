import Foundation

/// Codable DTO matching the Supabase `profiles` table shape.
/// Maps to/from the domain `Profile` entity.
struct ProfileDTO: Codable {
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
    var settings: UserSettings?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case grade
        case subjects
        case onboardingCompleted = "onboarding_completed"
        case referralSource = "referral_source"
        case major
        case studyGoal = "study_goal"
        case painPoints = "pain_points"
        case learningStyle = "learning_style"
        case favoriteTopic = "favorite_topic"
        case settings
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toDomain() -> Profile {
        Profile(
            id: id,
            displayName: displayName,
            email: email,
            grade: grade,
            subjects: subjects,
            onboardingCompleted: onboardingCompleted,
            referralSource: referralSource,
            major: major,
            studyGoal: studyGoal,
            painPoints: painPoints,
            learningStyle: learningStyle,
            favoriteTopic: favoriteTopic,
            settings: settings ?? UserSettings(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
