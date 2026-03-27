import SwiftUI

/// Slowly pulses toolbar icon brightness during walkthrough.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .brightness(isActive && pulse ? 0.3 : 0)
            .shadow(color: isActive && pulse ? Color(hex: 0xF5C28A).opacity(0.6) : .clear, radius: 4)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            .onChange(of: isActive) { _, active in
                pulse = active
            }
            .onAppear { if isActive { pulse = true } }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
