import SwiftUI

struct DocumentSkeletonView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 0) {
                    // Thumbnail placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReefColors.white.opacity(0.6))
                        .aspectRatio(8.5 / 11, contentMode: .fit)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)

                    // Title placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ReefColors.white.opacity(0.6))
                        .frame(width: 120, height: 13)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    // Status placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ReefColors.white.opacity(0.6))
                        .frame(width: 70, height: 11)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 14)
                }
                .background(ReefColors.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(0.8)
                .fadeUp(index: i)
            }
        }
    }
}
