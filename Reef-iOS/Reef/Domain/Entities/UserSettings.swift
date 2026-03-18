import Foundation

/// All user preferences and privacy settings, stored as a single JSONB blob
/// in the `settings` column of the `profiles` table.
///
/// Every field has a default value so decoding from `{}` or partial JSON
/// works without error — new settings can be added without a migration.
struct UserSettings: Codable, Sendable, Equatable {

    // MARK: - Profile Extras

    var avatarColorIndex: Int = 0
    var dailyGoalMinutes: Int = 30

    // MARK: - Appearance

    var compactMode: Bool = false
    var textScale: String = "Standard"

    // MARK: - Notifications

    var studyReminders: Bool = true
    var weeklyDigest: Bool = true
    var newFeatures: Bool = false
    var achievementAlerts: Bool = true
    var reminderTime: String = "Evening"

    // MARK: - Study Preferences

    var difficultyLevel: String = "Medium"
    var questionCount: Int = 10
    var timerEnabled: Bool = true
    var autoAdvance: Bool = false
    var shuffleQuestions: Bool = true

    // MARK: - Privacy — Analytics

    var analyticsEnabled: Bool = true
    var crashReporting: Bool = true
    var performanceMonitoring: Bool = true
    var sessionRecording: Bool = false

    // MARK: - Privacy — Data Sharing

    var personalisedContent: Bool = false
    var shareWithResearchers: Bool = false
    var profileVisibility: Bool = true
    var progressBenchmarking: Bool = false

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case avatarColorIndex = "avatar_color_index"
        case dailyGoalMinutes = "daily_goal_minutes"
        case compactMode = "compact_mode"
        case textScale = "text_scale"
        case studyReminders = "study_reminders"
        case weeklyDigest = "weekly_digest"
        case newFeatures = "new_features"
        case achievementAlerts = "achievement_alerts"
        case reminderTime = "reminder_time"
        case difficultyLevel = "difficulty_level"
        case questionCount = "question_count"
        case timerEnabled = "timer_enabled"
        case autoAdvance = "auto_advance"
        case shuffleQuestions = "shuffle_questions"
        case analyticsEnabled = "analytics_enabled"
        case crashReporting = "crash_reporting"
        case performanceMonitoring = "performance_monitoring"
        case sessionRecording = "session_recording"
        case personalisedContent = "personalised_content"
        case shareWithResearchers = "share_with_researchers"
        case profileVisibility = "profile_visibility"
        case progressBenchmarking = "progress_benchmarking"
    }

    // MARK: - Decode with defaults

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avatarColorIndex = try c.decodeIfPresent(Int.self, forKey: .avatarColorIndex) ?? 0
        dailyGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 30
        compactMode = try c.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        textScale = try c.decodeIfPresent(String.self, forKey: .textScale) ?? "Standard"
        studyReminders = try c.decodeIfPresent(Bool.self, forKey: .studyReminders) ?? true
        weeklyDigest = try c.decodeIfPresent(Bool.self, forKey: .weeklyDigest) ?? true
        newFeatures = try c.decodeIfPresent(Bool.self, forKey: .newFeatures) ?? false
        achievementAlerts = try c.decodeIfPresent(Bool.self, forKey: .achievementAlerts) ?? true
        reminderTime = try c.decodeIfPresent(String.self, forKey: .reminderTime) ?? "Evening"
        difficultyLevel = try c.decodeIfPresent(String.self, forKey: .difficultyLevel) ?? "Medium"
        questionCount = try c.decodeIfPresent(Int.self, forKey: .questionCount) ?? 10
        timerEnabled = try c.decodeIfPresent(Bool.self, forKey: .timerEnabled) ?? true
        autoAdvance = try c.decodeIfPresent(Bool.self, forKey: .autoAdvance) ?? false
        shuffleQuestions = try c.decodeIfPresent(Bool.self, forKey: .shuffleQuestions) ?? true
        analyticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .analyticsEnabled) ?? true
        crashReporting = try c.decodeIfPresent(Bool.self, forKey: .crashReporting) ?? true
        performanceMonitoring = try c.decodeIfPresent(Bool.self, forKey: .performanceMonitoring) ?? true
        sessionRecording = try c.decodeIfPresent(Bool.self, forKey: .sessionRecording) ?? false
        personalisedContent = try c.decodeIfPresent(Bool.self, forKey: .personalisedContent) ?? false
        shareWithResearchers = try c.decodeIfPresent(Bool.self, forKey: .shareWithResearchers) ?? false
        profileVisibility = try c.decodeIfPresent(Bool.self, forKey: .profileVisibility) ?? true
        progressBenchmarking = try c.decodeIfPresent(Bool.self, forKey: .progressBenchmarking) ?? false
    }
}
