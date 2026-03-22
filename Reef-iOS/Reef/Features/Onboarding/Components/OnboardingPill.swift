import SwiftUI

struct OnboardingPill: View {
    @Environment(ReefTheme.self) private var theme

    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = theme.colors

        Text(label)
            .font(.epilogue(13, weight: .semiBold))
            .tracking(-0.04 * 13)
            .foregroundStyle(isSelected ? ReefColors.white : colors.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? ReefColors.primary : colors.card)
            .clipShape(Capsule())
            .reef3DPushCapsule(
                borderWidth: 2,
                borderColor: colors.border,
                shadowColor: colors.shadow,
                action: action
            )
            .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
