//
//  TranscriptionDebugPanel.swift
//  Reef
//
//  Debug overlay showing real-time LaTeX transcription on the canvas.
//

#if DEBUG
import SwiftUI

struct TranscriptionDebugPanel: View {
    let questionIndex: Int
    let partLabel: String?
    let latex: String?

    @State private var katexHeight: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            if let latex, !latex.isEmpty {
                KaTeXView(
                    text: "$$\(Self.stripDelimiters(latex))$$",
                    fontSize: 14,
                    textColor: .primary,
                    maxHeight: 120,
                    contentHeight: $katexHeight
                )
                .frame(height: katexHeight)
                .frame(maxWidth: .infinity)

                // Raw LaTeX below for debugging
                Text(latex)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(width: 280, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    /// Strip math delimiters that Mathpix may include in its response.
    private static func stripDelimiters(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove outer display delimiters
        for (open, close) in [("$$", "$$"), ("\\[", "\\]")] {
            if t.hasPrefix(open) && t.hasSuffix(close) {
                t = String(t.dropFirst(open.count).dropLast(close.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Remove outer inline delimiters
        for (open, close) in [("\\(", "\\)"), ("$", "$")] {
            if t.hasPrefix(open) && t.hasSuffix(close) {
                t = String(t.dropFirst(open.count).dropLast(close.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return t
    }

    private var label: String {
        let base = "Q\(questionIndex + 1)"
        if let partLabel {
            return "\(base) (\(partLabel))"
        }
        return base
    }
}
#endif
