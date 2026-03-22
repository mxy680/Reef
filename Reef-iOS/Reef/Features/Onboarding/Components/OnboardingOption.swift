import SwiftUI

struct OnboardingOption: View {
    @Environment(ReefTheme.self) private var theme

    let label: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 12) {
            if let icon {
                Text(icon)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(isSelected ? ReefColors.white.opacity(0.8) : colors.textMuted)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(isSelected ? ReefColors.primary : colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .reef3DPush(
            cornerRadius: 12,
            borderWidth: 2,
            borderColor: colors.border,
            shadowColor: colors.shadow,
            action: action
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
