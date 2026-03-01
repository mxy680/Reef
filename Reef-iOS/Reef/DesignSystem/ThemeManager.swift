//
//  ThemeManager.swift
//  Reef
//
//  Dark/light mode toggle
//

import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }

    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    func toggle() {
        objectWillChange.send()
        isDarkMode.toggle()
    }
}
