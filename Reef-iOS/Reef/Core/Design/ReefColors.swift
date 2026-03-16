import SwiftUI
import UIKit

// MARK: - Color Palette

enum ReefColors {
    static let primary = Color(hex: 0x5B9EAD)
    static let accent = Color(hex: 0xA8D5D5)
    static let surface = Color(hex: 0xFCEBD5)
    static let white = Color.white
    static let black = Color.black
    static let error = Color(hex: 0xD32F2F)

    // MARK: - Grays

    static let gray600 = Color(red: 119 / 255, green: 119 / 255, blue: 119 / 255)
    static let gray500 = Color(red: 140 / 255, green: 140 / 255, blue: 140 / 255)
    static let gray400 = Color(red: 160 / 255, green: 160 / 255, blue: 160 / 255)
    static let gray200 = Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255)
    static let gray100 = Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)

    // MARK: - Dark Mode

    enum Dark {
        static let background = Color(hex: 0x1A1A1E)
        static let card = Color(hex: 0x242428)
        static let cardElevated = Color(hex: 0x2C2C32)

        static let text = Color(hex: 0xF0F0F0)
        static let textSecondary = Color(hex: 0x9A9AA0)
        static let textMuted = Color(hex: 0x7A7A82)
        static let textDisabled = Color(hex: 0x5A5A62)

        static let border = Color(hex: 0x4A4A52)
        static let shadow = Color(hex: 0x0F0F12)
        static let popupBorder = Color(hex: 0x5A5A62)
        static let popupShadow = Color(hex: 0x0A0A0D)

        static let divider = Color(hex: 0x3A3A40)
        static let subtle = Color(hex: 0x2A2A2E)
        static let surface = Color(hex: 0x2D261E)
        static let input = Color(hex: 0x2A2A30)
        static let inputBorder = Color(hex: 0x4A4A52)
        static let skeleton = Color(hex: 0x2E2E34)

        static let activeNavBg = Color(hex: 0x2A3D3D)
        static let activeNavBorder = Color(hex: 0x5B9EAD)
    }

    // MARK: - Canvas Dark Mode

    enum CanvasDark {
        static let background = Color(hex: 0x111114)
        static let safeArea = Color(hex: 0x0A0A0D)
        static let toolbar = Color(hex: 0x2F535B)
        static let pageBorder = Color(red: 60 / 255, green: 60 / 255, blue: 60 / 255)

        static let scrollBackground = UIColor(
            red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x14 / 255.0, alpha: 1
        )
        static let pageBorderUI = UIColor(
            red: 60 / 255.0, green: 60 / 255.0, blue: 60 / 255.0, alpha: 1
        )
    }
}

// MARK: - Semantic Color Resolution

/// Resolves colors based on the current theme. Use this instead of
/// inline ternaries scattered across views.
struct ReefThemeColors {
    let isDarkMode: Bool

    var surface: Color { isDarkMode ? ReefColors.Dark.surface : ReefColors.surface }
    var background: Color { isDarkMode ? ReefColors.Dark.background : ReefColors.surface }
    var card: Color { isDarkMode ? ReefColors.Dark.card : ReefColors.white }
    var text: Color { isDarkMode ? ReefColors.Dark.text : ReefColors.black }
    var textSecondary: Color { isDarkMode ? ReefColors.Dark.textSecondary : ReefColors.gray600 }
    var textMuted: Color { isDarkMode ? ReefColors.Dark.textMuted : ReefColors.gray500 }
    var border: Color { isDarkMode ? ReefColors.Dark.popupBorder : ReefColors.black }
    var shadow: Color { isDarkMode ? ReefColors.Dark.popupShadow : ReefColors.black }
    var input: Color { isDarkMode ? ReefColors.Dark.input : ReefColors.white }
    var inputBorder: Color { isDarkMode ? ReefColors.Dark.inputBorder : ReefColors.black }
    var divider: Color { isDarkMode ? ReefColors.Dark.divider : ReefColors.gray200 }
    var textDisabled: Color { isDarkMode ? ReefColors.Dark.textDisabled : ReefColors.gray400 }
    var subtle: Color { isDarkMode ? ReefColors.Dark.subtle : ReefColors.gray100 }
    var cardElevated: Color { isDarkMode ? ReefColors.Dark.cardElevated : ReefColors.white }
    var activeNavBg: Color { isDarkMode ? ReefColors.Dark.activeNavBg : ReefColors.accent }
    var activeNavBorder: Color { isDarkMode ? ReefColors.Dark.activeNavBorder : ReefColors.black }
}

// MARK: - Color(hex:) Initializer

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
