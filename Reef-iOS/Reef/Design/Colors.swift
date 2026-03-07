import SwiftUI

enum ReefColors {
    static let primary = Color(hex: 0x5B9EAD)
    static let accent = Color(hex: 0xA8D5D5)
    static let surface = Color(hex: 0xFCEBD5)
    static let white = Color.white
    static let black = Color.black
    static let gray600 = Color(red: 119 / 255, green: 119 / 255, blue: 119 / 255)
    static let gray500 = Color(red: 140 / 255, green: 140 / 255, blue: 140 / 255)
    static let gray400 = Color(red: 160 / 255, green: 160 / 255, blue: 160 / 255)
    static let gray200 = Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255)
    static let gray100 = Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)
    static let error = Color(hex: 0xD32F2F)

    // MARK: - Canvas Dark Mode

    enum CanvasDark {
        static let background = Color(hex: 0x1A1A1E)
        static let safeArea = Color(hex: 0x0F0F12)
        static let pageFill = Color(hex: 0x2A2A2E)
        static let pageBorder = Color(red: 80/255, green: 80/255, blue: 80/255)
        static let pageShadow = Color(red: 0, green: 0, blue: 0).opacity(0.5)

        // UIKit equivalents
        static let scrollBackground = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1E/255.0, alpha: 1)
        static let pageBackgroundUI = UIColor(red: 0x2A/255.0, green: 0x2A/255.0, blue: 0x2E/255.0, alpha: 1)
        static let pageBorderUI = UIColor(red: 80/255.0, green: 80/255.0, blue: 80/255.0, alpha: 1)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(hex string: String) {
        let hex = string.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(hex: UInt(value))
    }
}
