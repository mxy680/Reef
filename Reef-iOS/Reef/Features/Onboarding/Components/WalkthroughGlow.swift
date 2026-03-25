import SwiftUI

/// Pulsing glow effect applied to toolbar icons during the walkthrough tutorial.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false
    @State private var ringScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                isActive
                    ? ZStack {
                        // Outer expanding ring
                        Circle()
                            .stroke(ReefColors.primary.opacity(isPulsing ? 0.0 : 0.4), lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .scaleEffect(ringScale)

                        // Inner glow
                        Circle()
                            .fill(ReefColors.primary.opacity(isPulsing ? 0.35 : 0.15))
                            .frame(width: 38, height: 38)
                            .blur(radius: 10)
                    }
                    .allowsHitTesting(false)
                    : nil
            )
            .onAppear {
                if isActive { startGlow() }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startGlow()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPulsing = false
                        ringScale = 1.0
                    }
                }
            }
    }

    private func startGlow() {
        isPulsing = false
        ringScale = 1.0
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
            ringScale = 1.6
        }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
