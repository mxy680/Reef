import SwiftUI

// MARK: - Epilogue Font

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

// MARK: - Semantic Text Styles

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

    func reefCaption() -> some View {
        self.font(.epilogue(13, weight: .medium))
            .tracking(-0.02 * 13)
    }

    func reefLabel() -> some View {
        self.font(.epilogue(14, weight: .medium))
            .tracking(-0.04 * 14)
    }
}
