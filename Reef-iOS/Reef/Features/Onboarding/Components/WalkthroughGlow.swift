import SwiftUI

/// Slowly pulses toolbar icon color between tan and white during walkthrough.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false

    private let tanColor = Color(hex: 0xF5C28A)

    func body(content: Content) -> some View {
        content
            .foregroundColor(isActive ? (isPulsing ? tanColor : .white) : nil)
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
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
