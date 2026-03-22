import SwiftUI

struct OnboardingPill: View {
    @Environment(ReefTheme.self) private var theme

    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 6) {
            Text(label)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(isSelected ? ReefColors.white : colors.text)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ReefColors.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
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
