import SwiftUI

/// Pulsing green dot on the top-right of toolbar icons during the walkthrough tutorial.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Circle()
                        .fill(Color(hex: 0x4CAF50))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.4 : 1.0)
                        .opacity(isPulsing ? 0.6 : 1.0)
                        .offset(x: 2, y: -2)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if isActive { startPulse() }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startPulse()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPulsing = false
                    }
                }
            }
    }

    private func startPulse() {
        isPulsing = false
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
