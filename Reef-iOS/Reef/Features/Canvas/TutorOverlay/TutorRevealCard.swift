import SwiftUI

struct TutorRevealCard: View {
    @Environment(ReefTheme.self) private var theme
    let workText: String
    let stepLabel: String
    let isDarkMode: Bool
    let onClose: () -> Void

    var body: some View {
        let colors = theme.colors

        DraggableCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReefColors.primary)

                    Text("Answer")
                        .font(.epilogue(13, weight: .black))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.text)

                    Spacer()

                    Text(stepLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(colors.textMuted)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(colors.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(colors.subtle)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                MathText(
                    text: workText,
                    fontSize: 13,
                    color: colors.text
                )
            }
            .padding(14)
            .frame(width: 260)
            .background(colors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colors.border, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colors.shadow)
                    .offset(x: 4, y: 4)
            )
        }
    }
}
