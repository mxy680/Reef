//
//  MathText.swift
//  Reef
//
//  Renders mixed text + LaTeX using KaTeX via WKWebView.
//  Falls back to plain SwiftUI Text for non-LaTeX strings.
//

import SwiftUI

/// Renders a string containing LaTeX math.
/// Detects `$...$`, `\[...\]`, `\(...\)` delimiters or common LaTeX commands
/// and renders via KaTeX in a WKWebView. Falls back to plain Text otherwise.
struct MathText: View {
    let text: String
    var fontSize: CGFloat = 13
    var color: Color = ReefColors.gray600
    var maxHeight: CGFloat = 300

    /// Matches dollar-delimited LaTeX, display math, or common LaTeX commands.
    private static let latexPattern = try! NSRegularExpression(
        pattern: #"\$|\\\[|\\\]|\\\(|\\\)|\\(?:frac|sqrt|text|sum|int|lim|theta|alpha|beta|gamma|delta|sigma|pi|infty|cdot|times|div|pm|leq|geq|neq|approx|quad|left|right|begin|end|over|hat|bar|vec|dot|log|ln|sin|cos|tan|sec|csc|cot|cap|cup|mid|mathbb|mathrm|mathbf)"#
    )

    private var hasLatex: Bool {
        let range = NSRange(text.startIndex..., in: text)
        return Self.latexPattern.firstMatch(in: text, range: range) != nil
    }

    /// Starts small; KaTeXView reports actual height after render.
    @State private var contentHeight: CGFloat = 20

    var body: some View {
        if hasLatex {
            KaTeXView(
                text: Self.sanitizeLatex(text),
                fontSize: fontSize,
                textColor: color,
                maxHeight: maxHeight,
                contentHeight: $contentHeight
            )
            .frame(height: contentHeight)
            .clipped()
            .animation(.easeOut(duration: 0.2), value: contentHeight)
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(color)
        }
    }

    /// Normalize common LaTeX issues that cause KaTeX rendering failures.
    private static func sanitizeLatex(_ input: String) -> String {
        var s = input

        // Replace \[ \] with $$ $$ (KaTeX auto-render handles both, but normalize)
        s = s.replacingOccurrences(of: "\\[", with: "$$")
        s = s.replacingOccurrences(of: "\\]", with: "$$")

        // Replace \( \) with $ $
        s = s.replacingOccurrences(of: "\\(", with: "$")
        s = s.replacingOccurrences(of: "\\)", with: "$")

        // Fix double-escaped backslashes from JSON: \\frac → \frac (inside $ delimiters)
        // Only fix common LaTeX commands that shouldn't be double-escaped
        let commands = ["frac", "sqrt", "text", "textbf", "mathrm", "mathbf", "mathbb",
                        "sum", "int", "lim", "log", "ln", "sin", "cos", "tan",
                        "theta", "alpha", "beta", "gamma", "delta", "sigma", "pi",
                        "infty", "cdot", "times", "div", "pm", "leq", "geq", "neq",
                        "approx", "quad", "left", "right", "begin", "end",
                        "over", "hat", "bar", "vec", "dot", "circ",
                        "rightarrow", "leftarrow", "Rightarrow", "Leftarrow",
                        "forall", "exists", "partial", "nabla", "in", "notin",
                        "subset", "supset", "cup", "cap", "vspace", "hspace",
                        "displaystyle", "textstyle", "operatorname"]
        for cmd in commands {
            s = s.replacingOccurrences(of: "\\\\\(cmd)", with: "\\\(cmd)")
        }

        // Ensure bare LaTeX content (no delimiters) gets wrapped
        // If the string has LaTeX commands but no $ or $$ delimiters, wrap it
        if !s.contains("$") {
            let hasCmd = Self.latexPattern.firstMatch(
                in: s, range: NSRange(s.startIndex..., in: s)
            ) != nil
            if hasCmd {
                s = "$\(s)$"
            }
        }

        return s
    }
}
