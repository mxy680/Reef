//
//  MathText.swift
//  Reef
//
//  Renders mixed text + LaTeX using LaTeXSwiftUI.
//  Wraps the LaTeX view with Reef-specific defaults.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders a string containing inline LaTeX (delimited by `$...$` or `$$...$$`).
/// Falls back to plain Text if the string has no LaTeX delimiters.
struct MathText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)
    var color: Color = ReefColors.gray600

    private var hasLatex: Bool {
        text.contains("$")
    }

    var body: some View {
        if hasLatex {
            LaTeX(text)
                .font(font)
                .foregroundStyle(color)
                .parsingMode(.all)
                .blockMode(.alwaysInline)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(color)
        }
    }
}
