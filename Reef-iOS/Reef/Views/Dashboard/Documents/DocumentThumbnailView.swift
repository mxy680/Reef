import SwiftUI

struct DocumentThumbnailView: View {
    let status: DocumentStatus
    let thumbnailURL: URL?
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(status == .failed ? Color(hex: 0xFFF5F5) : (dark ? ReefColors.DashboardDark.subtle : Color(hex: 0xFAFAFA)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            status == .failed ? Color(hex: 0xFFCDD2) : (dark ? ReefColors.DashboardDark.divider : ReefColors.gray100),
                            lineWidth: 1
                        )
                )

            if let url = thumbnailURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        Group {
                            if dark {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .colorInvert()
                            } else {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            }
                        }
                        .transition(.opacity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var ruledLines: some View {
        let dark = theme.isDarkMode
        return GeometryReader { geo in
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
                .stroke(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100, lineWidth: 0.5)
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
