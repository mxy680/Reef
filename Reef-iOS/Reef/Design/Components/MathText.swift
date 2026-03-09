//
//  MathText.swift
//  Reef
//
//  Renders mixed text + LaTeX using KaTeX via WKWebView.
//  Falls back to plain SwiftUI Text for non-LaTeX strings.
//

import SwiftUI

/// Renders a string containing LaTeX math.
/// Detects `$...$` delimiters or common LaTeX commands (`\frac`, `\sqrt`, etc.)
/// and renders via KaTeX in a WKWebView. Falls back to plain Text otherwise.
struct MathText: View {
    let text: String
    var fontSize: CGFloat = 13
    var color: Color = ReefColors.gray600

    /// Matches dollar-delimited LaTeX or common LaTeX commands.
    private static let latexPattern = try! NSRegularExpression(
        pattern: #"\$|\\(?:frac|sqrt|text|sum|int|lim|theta|alpha|beta|gamma|delta|sigma|pi|infty|cdot|times|div|pm|leq|geq|neq|approx|quad|left|right|begin|end|over|hat|bar|vec|dot|log|ln|sin|cos|tan|sec|csc|cot)"#
    )

    private var hasLatex: Bool {
        let range = NSRange(text.startIndex..., in: text)
        return Self.latexPattern.firstMatch(in: text, range: range) != nil
    }

    @State private var contentHeight: CGFloat = 100

    var body: some View {
        if hasLatex {
            KaTeXView(
                text: text,
                fontSize: fontSize,
                textColor: color,
                contentHeight: $contentHeight
            )
            .frame(height: contentHeight)
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(color)
        }
    }
}
