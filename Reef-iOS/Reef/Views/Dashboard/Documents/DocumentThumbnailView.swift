import SwiftUI

struct DocumentThumbnailView: View {
    let status: DocumentStatus
    let thumbnailURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(status == .failed ? Color(hex: 0xFFF5F5) : Color(hex: 0xFAFAFA))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            status == .failed ? Color(hex: 0xFFCDD2) : ReefColors.gray100,
                            lineWidth: 1
                        )
                )

            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        ruledLines
                    }
                }
            } else {
                ruledLines
            }

            if status == .processing {
                ShimmerOverlay()
            }
        }
        .aspectRatio(8.5 / 11, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var ruledLines: some View {
        GeometryReader { geo in
            let lineCount = 16
            let topInset = geo.size.height * 0.14
            let spacing = (geo.size.height * 0.72) / CGFloat(lineCount)
            let hPad = geo.size.width * 0.12

            ForEach(0..<lineCount, id: \.self) { i in
                Path { path in
                    let y = topInset + CGFloat(i) * spacing
                    path.move(to: CGPoint(x: hPad, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width - hPad, y: y))
                }
                .stroke(ReefColors.gray100, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Shimmer Overlay

struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    ReefColors.primary.opacity(0.08),
                    .clear,
                ],
                startPoint: .init(x: phase, y: 0.5),
                endPoint: .init(x: phase + 0.5, y: 0.5)
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
