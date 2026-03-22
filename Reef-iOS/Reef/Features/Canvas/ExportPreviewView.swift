import SwiftUI
import PDFKit

struct ExportPreviewView: View {
    @Environment(ReefTheme.self) private var theme
    let pdfData: Data
    let documentName: String
    let onShare: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(colors.subtle)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Export Preview")
                    .font(.epilogue(16, weight: .black))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(colors.text)

                Spacer()

                ReefModalButton("Share", action: onShare)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(colors.card)

            // PDF Preview
            PDFPreviewRepresentable(data: pdfData)
                .background(Color(hex: 0xE8E0D4))
        }
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors.border, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.shadow)
                .offset(x: 4, y: 4)
        )
    }
}

// MARK: - PDFKit Preview

private struct PDFPreviewRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 0.91, green: 0.88, blue: 0.83, alpha: 1)
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil {
            pdfView.document = PDFDocument(data: data)
        }
    }
}
