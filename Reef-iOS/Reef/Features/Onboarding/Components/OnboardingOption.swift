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

        HStack(spacing: 14) {
            if let icon {
                Text(icon)
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.epilogue(16, weight: .bold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.epilogue(13, weight: .medium))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(isSelected ? ReefColors.white.opacity(0.8) : colors.textMuted)
                        .italic()
                }
            }

            Spacer()

            // Checkmark when selected
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ReefColors.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(isSelected ? ReefColors.primary : colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .reef3DPush(
            cornerRadius: 14,
            shadowOffset: 5,
            borderWidth: 2,
            borderColor: colors.border,
            shadowColor: colors.shadow,
            action: action
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
