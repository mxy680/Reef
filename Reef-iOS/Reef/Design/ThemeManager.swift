import SwiftUI

@Observable
@MainActor
final class ThemeManager {
    var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "reef_dark_mode") }
    }

    init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "reef_dark_mode")
    }
}
