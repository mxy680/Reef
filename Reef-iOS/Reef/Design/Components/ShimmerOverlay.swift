import SwiftUI

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
