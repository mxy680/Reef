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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(latex ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding(8)
        .frame(maxWidth: 260, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
