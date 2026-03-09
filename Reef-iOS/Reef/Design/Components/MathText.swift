//
//  MathText.swift
//  Reef
//
//  Renders mixed text + LaTeX using LaTeXSwiftUI.
//  Wraps the LaTeX view with Reef-specific defaults.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders a string containing LaTeX math.
/// Detects `$...$` delimiters or bare LaTeX commands (`\frac`, `\sqrt`, etc.)
/// and renders via LaTeXSwiftUI. Falls back to plain Text otherwise.
struct MathText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)
    var color: Color = ReefColors.gray600

    /// Matches dollar-delimited LaTeX or common LaTeX commands.
    private static let latexPattern = try! NSRegularExpression(
        pattern: #"\$|\\(?:frac|sqrt|text|sum|int|lim|theta|alpha|beta|gamma|delta|sigma|pi|infty|cdot|times|div|pm|leq|geq|neq|approx|quad|left|right|begin|end|over|hat|bar|vec|dot|log|ln|sin|cos|tan|sec|csc|cot)"#
    )

    private var hasLatex: Bool {
        let range = NSRange(text.startIndex..., in: text)
        return Self.latexPattern.firstMatch(in: text, range: range) != nil
    }

    /// Wraps bare LaTeX (no `$` delimiters) in `$...$` so the renderer picks it up.
    /// Processes each line independently — lines that already have `$` are left alone,
    /// while lines with bare LaTeX commands get wrapped.
    private var processedText: String {
        return text.components(separatedBy: "\n").map { line in
            // If line already contains $ delimiters, leave it as-is
            if line.contains("$") { return line }
            let range = NSRange(line.startIndex..., in: line)
            if Self.latexPattern.firstMatch(in: line, range: range) != nil {
                return "$\(line)$"
            }
            return line
        }.joined(separator: "\n")
    }

    var body: some View {
        if hasLatex {
            LaTeX(processedText)
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
