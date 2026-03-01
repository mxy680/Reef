import SwiftUI

struct DocumentEmptyStateView: View {
    let onUpload: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ReefColors.gray400)

            Text("No documents yet")
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)
                .foregroundStyle(ReefColors.black)
                .padding(.top, 20)

            Text("Upload a PDF to get started with Reef.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
                .padding(.top, 6)

            Button("Upload Document") {
                onUpload()
            }
            .reefStyle(.primary)
            .frame(width: 200)
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(ReefColors.gray400)
        )
    }
}
