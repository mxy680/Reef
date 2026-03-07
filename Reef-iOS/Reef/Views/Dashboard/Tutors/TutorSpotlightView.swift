import SwiftUI

struct TutorSpotlightView: View {
    let tutor: Tutor
    let isSpeaking: Bool
    let onVoicePreview: () -> Void
    let onStartSession: () -> Void
    var avatarSize: CGFloat = 120

    @Environment(ThemeManager.self) private var theme

    private var tintColor: Color {
        Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
    }

    var body: some View {
        let dark = theme.isDarkMode
        return HStack(alignment: .top, spacing: 20) {
            // Left: avatar circle
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.15))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Circle()
                            .stroke(tintColor.opacity(0.3), lineWidth: 2)
                    )

                Text(tutor.emoji)
                    .font(.system(size: avatarSize * 0.47))
            }

            // Right: info + actions
            VStack(alignment: .leading, spacing: 6) {
                Text(tutor.name)
                    .font(.epilogue(22, weight: .black))
                    .tracking(-0.04 * 22)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                Text(tutor.species.uppercased())
                    .font(.epilogue(11, weight: .bold))
                    .tracking(0.06 * 11)
                    .foregroundStyle(tintColor)

                Text(tutor.teachingStyle)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                    .lineLimit(4)
                    .padding(.top, 2)

                // Voice description pill
                HStack(spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                    Text(tutor.voiceDescription)
                        .font(.epilogue(11, weight: .semiBold))
                        .tracking(-0.04 * 11)
                }
                .foregroundStyle(tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tintColor.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 4)
                .padding(.bottom, 6)

                // Bottom actions
                HStack(spacing: 10) {
                    Button {
                        onVoicePreview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Preview Voice")
                        }
                    }
                    .reefCompactStyle(.secondary)

                    Button {
                        onStartSession()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Start Session")
                        }
                    }
                    .reefCompactStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tintColor, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tintColor)
                .offset(x: 4, y: 4)
        )
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }
}
