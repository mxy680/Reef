import Foundation

enum Tier: String {
    case shore, reef, abyss
}

struct TierLimits {
    let maxDocuments: Int
    let maxFileSizeMB: Int
    let maxCourses: Int

    static let shore = TierLimits(maxDocuments: 5, maxFileSizeMB: 20, maxCourses: 1)
    static let reef = TierLimits(maxDocuments: 50, maxFileSizeMB: 50, maxCourses: 5)
    static let abyss = TierLimits(maxDocuments: Int.max, maxFileSizeMB: 100, maxCourses: Int.max)

    static func forTier(_ tier: Tier) -> TierLimits {
        switch tier {
        case .shore: .shore
        case .reef: .reef
        case .abyss: .abyss
        }
    }

    // Hardcoded to shore until billing ships (matches web)
    static func current() -> TierLimits { .shore }
}
