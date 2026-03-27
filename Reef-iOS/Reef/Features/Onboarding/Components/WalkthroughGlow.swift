import SwiftUI

/// Slowly pulses toolbar icon tint between tan and white during walkthrough.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var pulse = false

    private let tan = Color(hex: 0xF5C28A)

    func body(content: Content) -> some View {
        content
            .colorMultiply(isActive ? (pulse ? tan : .white) : .white)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            .onAppear { if isActive { pulse = true } }
            .onChange(of: isActive) { _, active in
                pulse = active
            }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
