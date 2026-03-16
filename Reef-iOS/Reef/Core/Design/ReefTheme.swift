import SwiftUI

// MARK: - Theme Manager

@Observable
@MainActor
final class ReefTheme {
    var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "reef_dark_mode") }
    }

    /// Semantic colors resolved for the current theme.
    var colors: ReefThemeColors { ReefThemeColors(isDarkMode: isDarkMode) }

    init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "reef_dark_mode")
    }
}
