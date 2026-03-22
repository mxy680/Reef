import Foundation

/// Converts simple LaTeX math to Unicode text for inline display (no WKWebView).
/// Handles common symbols used in step descriptions.
enum LaTeXToUnicode {
    static func convert(_ input: String) -> String {
        var s = input

        // Strip math delimiters
        s = s.replacingOccurrences(of: "$$", with: "")
        s = s.replacingOccurrences(of: "$", with: "")
        s = s.replacingOccurrences(of: "\\[", with: "")
        s = s.replacingOccurrences(of: "\\]", with: "")
        s = s.replacingOccurrences(of: "\\(", with: "")
        s = s.replacingOccurrences(of: "\\)", with: "")

        // Greek letters
        let greek: [(String, String)] = [
            ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
            ("\\epsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"), ("\\theta", "θ"),
            ("\\lambda", "λ"), ("\\mu", "μ"), ("\\nu", "ν"), ("\\pi", "π"),
            ("\\rho", "ρ"), ("\\sigma", "σ"), ("\\tau", "τ"), ("\\phi", "φ"),
            ("\\chi", "χ"), ("\\psi", "ψ"), ("\\omega", "ω"),
            ("\\Delta", "Δ"), ("\\Sigma", "Σ"), ("\\Pi", "Π"), ("\\Omega", "Ω"),
        ]
        for (latex, unicode) in greek {
            s = s.replacingOccurrences(of: latex, with: unicode)
        }

        // Operators and symbols
        let symbols: [(String, String)] = [
            ("\\cap", "∩"), ("\\cup", "∪"), ("\\in", "∈"), ("\\notin", "∉"),
            ("\\subset", "⊂"), ("\\supset", "⊃"), ("\\subseteq", "⊆"), ("\\supseteq", "⊇"),
            ("\\times", "×"), ("\\cdot", "·"), ("\\div", "÷"), ("\\pm", "±"),
            ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
            ("\\infty", "∞"), ("\\rightarrow", "→"), ("\\leftarrow", "←"),
            ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"),
            ("\\forall", "∀"), ("\\exists", "∃"), ("\\partial", "∂"),
            ("\\nabla", "∇"), ("\\sqrt", "√"), ("\\sum", "Σ"), ("\\prod", "∏"),
            ("\\int", "∫"), ("\\circ", "°"),
        ]
        for (latex, unicode) in symbols {
            s = s.replacingOccurrences(of: latex, with: unicode)
        }

        // \text{...} → content
        while let range = s.range(of: #"\\text\{([^}]*)\}"#, options: .regularExpression) {
            let match = String(s[range])
            let content = match
                .replacingOccurrences(of: "\\text{", with: "")
                .replacingOccurrences(of: "}", with: "")
            s = s.replacingCharacters(in: range, with: content)
        }

        // \frac{a}{b} → a/b
        while let range = s.range(of: #"\\frac\{([^}]*)\}\{([^}]*)\}"#, options: .regularExpression) {
            let match = String(s[range])
            // Extract numerator and denominator
            var inner = match.replacingOccurrences(of: "\\frac{", with: "")
            inner.removeLast() // trailing }
            let parts = inner.components(separatedBy: "}{")
            if parts.count == 2 {
                s = s.replacingCharacters(in: range, with: "\(parts[0])/\(parts[1])")
            } else {
                break
            }
        }

        // Superscripts: ^{...} or ^x
        let superscriptMap: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "n": "ⁿ", "i": "ⁱ", "c": "ᶜ",
        ]
        // ^{content}
        while let range = s.range(of: #"\^\{([^}]*)\}"#, options: .regularExpression) {
            let match = String(s[range])
            let content = match.replacingOccurrences(of: "^{", with: "").replacingOccurrences(of: "}", with: "")
            let converted = String(content.map { superscriptMap[$0] ?? $0 })
            s = s.replacingCharacters(in: range, with: converted)
        }
        // ^single_char
        while let range = s.range(of: #"\^([0-9nic])"#, options: .regularExpression) {
            let match = String(s[range])
            let ch = match.last!
            let converted = superscriptMap[ch].map(String.init) ?? String(ch)
            s = s.replacingCharacters(in: range, with: converted)
        }

        // Subscripts: _{...} or _x
        let subscriptMap: [Character: Character] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "a": "ₐ", "e": "ₑ", "i": "ᵢ", "n": "ₙ", "x": "ₓ",
        ]
        while let range = s.range(of: #"_\{([^}]*)\}"#, options: .regularExpression) {
            let match = String(s[range])
            let content = match.replacingOccurrences(of: "_{", with: "").replacingOccurrences(of: "}", with: "")
            let converted = String(content.map { subscriptMap[$0] ?? $0 })
            s = s.replacingCharacters(in: range, with: converted)
        }
        while let range = s.range(of: #"_([0-9aeinx])"#, options: .regularExpression) {
            let match = String(s[range])
            let ch = match.last!
            let converted = subscriptMap[ch].map(String.init) ?? String(ch)
            s = s.replacingCharacters(in: range, with: converted)
        }

        // Clean up remaining backslashes from unrecognized commands
        s = s.replacingOccurrences(of: "\\", with: "")

        // Clean up extra whitespace
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        return s.trimmingCharacters(in: .whitespaces)
    }
}
