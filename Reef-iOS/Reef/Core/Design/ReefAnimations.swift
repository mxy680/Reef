import SwiftUI

// MARK: - FadeUp Staggered Animation

struct FadeUp: ViewModifier {
    let index: Int
    @State private var isVisible = false

    private var delay: Double { 0.3 + 0.05 * Double(index) }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

extension View {
    func fadeUp(index: Int) -> some View {
        modifier(FadeUp(index: index))
    }
}
