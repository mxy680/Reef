import SwiftUI

// MARK: - Responsive Layout Metrics

struct ReefLayoutMetrics {
    let screenHeight: CGFloat

    /// Continuous scale: 0.0 at iPad mini (744pt) → 1.0 at iPad Pro 13" (1032pt)
    var scale: CGFloat {
        let lo: CGFloat = 744
        let hi: CGFloat = 1032
        return max(0, min(1, (screenHeight - lo) / (hi - lo)))
    }

    // MARK: - Dashboard Chrome

    var sidebarOpenWidth: CGFloat { lerp(240, 280) }
    var sidebarCollapsedWidth: CGFloat { lerp(60, 72) }
    var headerHeight: CGFloat { lerp(56, 72) }

    // MARK: - Content Padding

    var contentPadding: CGFloat { lerp(24, 36) }
    var cardPadding: CGFloat { lerp(20, 28) }
    var sectionSpacing: CGFloat { lerp(14, 20) }

    // MARK: - Grid

    var gridColumnMin: CGFloat { lerp(170, 200) }
    var gridColumnMax: CGFloat { lerp(210, 250) }

    // MARK: - Tutor Cards

    var tutorCardWidth: CGFloat { lerp(210, 240) }
    var tutorCardHeight: CGFloat { lerp(230, 260) }
    var spotlightAvatarSize: CGFloat { lerp(100, 140) }

    // MARK: - Analytics

    var chartHeight: CGFloat { lerp(180, 240) }
    var chartCardPadding: CGFloat { lerp(16, 24) }
    var statCardVPadding: CGFloat { lerp(14, 20) }

    // MARK: - Settings

    var profileRingSize: CGFloat { lerp(80, 112) }

    // MARK: - Helpers

    private func lerp(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + (hi - lo) * scale
    }
}

// MARK: - Environment Key

private struct ReefLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = ReefLayoutMetrics(screenHeight: 834)
}

extension EnvironmentValues {
    var layoutMetrics: ReefLayoutMetrics {
        get { self[ReefLayoutMetricsKey.self] }
        set { self[ReefLayoutMetricsKey.self] = newValue }
    }
}
