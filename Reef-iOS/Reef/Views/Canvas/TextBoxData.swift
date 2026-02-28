//
//  TextBoxData.swift
//  Reef
//
//  Data model for text box annotations on canvas pages
//

import UIKit

struct TextBoxData: Codable, Identifiable {
    let id: UUID
    var x: CGFloat          // position relative to page (in canvas coordinates)
    var y: CGFloat
    var width: CGFloat
    var text: String
    var fontSize: CGFloat
    var colorHex: String    // stored as hex for Codable

    init(id: UUID = UUID(), x: CGFloat, y: CGFloat, width: CGFloat = 200, text: String = "", fontSize: CGFloat = 16, colorHex: String = "#000000") {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.text = text
        self.fontSize = fontSize
        self.colorHex = colorHex
    }

    var uiColor: UIColor {
        UIColor(hex: colorHex) ?? .black
    }

    static func hexFromUIColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
