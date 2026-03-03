import SwiftUI

struct DocumentSkeletonView: View {
    @Environment(\.layoutMetrics) private var metrics

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: metrics.gridColumnMin, maximum: metrics.gridColumnMax), spacing: 20)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 0) {
                    // Thumbnail placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReefColors.white.opacity(0.6))
                        .aspectRatio(8.5 / 10, contentMode: .fit)
                        .padding(.horizontal, 10)
                        .padding(.top, 10)

                    // Divider placeholder
                    Rectangle()
                        .fill(ReefColors.white.opacity(0.4))
                        .frame(height: 1)
                        .padding(.top, 10)

                    // Title placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ReefColors.white.opacity(0.6))
                        .frame(width: 120, height: 13)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)

                    // Status placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ReefColors.white.opacity(0.6))
                        .frame(width: 70, height: 11)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                }
                .background(ReefColors.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(0.8)
                .fadeUp(index: i)
            }
        }
    }
}
