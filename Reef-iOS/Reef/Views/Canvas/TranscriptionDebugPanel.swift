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
                    text: "$$\(latex)$$",
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

    private var label: String {
        let base = "Q\(questionIndex + 1)"
        if let partLabel {
            return "\(base) (\(partLabel))"
        }
        return base
    }
}
#endif
