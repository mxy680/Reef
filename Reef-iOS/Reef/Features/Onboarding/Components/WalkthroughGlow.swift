import SwiftUI

/// Pulsing glow effect applied to toolbar icons during the walkthrough tutorial.
struct WalkthroughGlow: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .background(
                isActive
                    ? Circle()
                        .fill(ReefColors.primary.opacity(isPulsing ? 0.5 : 0.25))
                        .frame(width: 36, height: 36)
                        .blur(radius: 8)
                    : nil
            )
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    isPulsing = false
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPulsing = false
                    }
                }
            }
    }
}

extension View {
    func walkthroughGlow(active: Bool) -> some View {
        modifier(WalkthroughGlow(isActive: active))
    }
}
