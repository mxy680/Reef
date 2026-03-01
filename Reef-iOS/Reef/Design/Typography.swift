import SwiftUI

extension Font {
    static func epilogue(_ size: CGFloat, weight: EpilogueWeight = .medium) -> Font {
        .custom("Epilogue-\(weight.rawValue)", size: size)
    }
}

enum EpilogueWeight: String {
    case medium = "Medium"
    case semiBold = "SemiBold"
    case bold = "Bold"
    case black = "Black"
}

// MARK: - Semantic helpers

extension View {
    func reefHeading() -> some View {
        self.font(.epilogue(32, weight: .black))
            .tracking(-0.04 * 32)
            .textCase(.uppercase)
            .foregroundStyle(ReefColors.black)
    }

    func reefBody() -> some View {
        self.font(.epilogue(15, weight: .medium))
            .tracking(-0.04 * 15)
            .foregroundStyle(ReefColors.gray600)
    }

    func reefButton() -> some View {
        self.font(.epilogue(16, weight: .bold))
            .tracking(-0.04 * 16)
    }
}

// MARK: - FadeUp animation modifier

struct FadeUp: ViewModifier {
    let index: Int
    @State private var isVisible = false

    private var delay: Double {
        0.3 + 0.05 * Double(index)
    }

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
