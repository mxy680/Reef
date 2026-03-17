import SwiftUI

struct DocumentEmptyStateView: View {
    let onUpload: () -> Void
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        return VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(colors.textDisabled)

            Text("No documents yet")
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)
                .foregroundStyle(colors.text)
                .padding(.top, 20)

            Text("Upload a PDF to get started with Reef.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 6)

            ReefButton("Upload Document", variant: .primary, size: .compact) {
                onUpload()
            }
            .frame(width: 200)
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(colors.textDisabled)
        )
    }
}
