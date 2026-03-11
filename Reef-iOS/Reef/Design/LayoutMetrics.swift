import SwiftUI

struct LayoutMetrics {
    let screenHeight: CGFloat

    // Continuous scale: 0.0 at iPad mini (744pt) → 1.0 at iPad Pro 13" (1032pt)
    var scale: CGFloat {
        let lo: CGFloat = 744
        let hi: CGFloat = 1032
        return max(0, min(1, (screenHeight - lo) / (hi - lo)))
    }

    // MARK: - Dashboard chrome

    var sidebarOpenWidth: CGFloat      { lerp(240, 280) }
    var sidebarCollapsedWidth: CGFloat { lerp(60, 72) }
    var headerHeight: CGFloat          { lerp(56, 72) }

    // MARK: - Content padding

    var contentPadding: CGFloat  { lerp(24, 36) }   // Analytics, Tutors, Settings outer
    var cardPadding: CGFloat     { lerp(20, 28) }    // Documents / CourseDetail inner
    var sectionSpacing: CGFloat  { lerp(14, 20) }    // VStack / HStack spacing inside pages

    // MARK: - Document / Course grid

    var gridColumnMin: CGFloat { lerp(170, 200) }
    var gridColumnMax: CGFloat { lerp(210, 250) }

    // MARK: - Tutor cards

    var tutorCardWidth: CGFloat     { lerp(210, 240) }
    var tutorCardHeight: CGFloat    { lerp(230, 260) }
    var spotlightAvatarSize: CGFloat { lerp(100, 140) }

    // MARK: - Analytics

    var chartHeight: CGFloat       { lerp(180, 240) }
    var chartCardPadding: CGFloat  { lerp(16, 24) }
    var statCardVPadding: CGFloat  { lerp(14, 20) }

    // MARK: - Settings

    var profileRingSize: CGFloat { lerp(80, 112) }

    // MARK: - Helpers

    private func lerp(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + (hi - lo) * scale
    }
}

// MARK: - Environment

private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics(screenHeight: 834)
}

extension EnvironmentValues {
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}
