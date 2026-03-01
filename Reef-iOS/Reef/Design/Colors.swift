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
}
