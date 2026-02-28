//
//  SkeletonShimmer.swift
//  Reef
//
//  Reusable shimmer overlay for skeleton loading states.
//

import SwiftUI

/// Animated shimmer overlay that sweeps across a skeleton placeholder.
struct SkeletonShimmerView: View {
    let colorScheme: ColorScheme
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.6)
                .offset(x: shimmerOffset * width)
        }
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}
