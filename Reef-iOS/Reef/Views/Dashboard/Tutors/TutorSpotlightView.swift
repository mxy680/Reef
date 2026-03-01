import SwiftUI

struct TutorSpotlightView: View {
    let tutor: Tutor
    let isSpeaking: Bool
    let onVoicePreview: () -> Void
    let onStartSession: () -> Void

    private var tintColor: Color {
        Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left: avatar circle
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(tintColor.opacity(0.3), lineWidth: 2)
                    )

                Text(tutor.emoji)
                    .font(.system(size: 56))
            }

            // Right: info + actions
            VStack(alignment: .leading, spacing: 6) {
                Text(tutor.name)
                    .font(.epilogue(22, weight: .black))
                    .tracking(-0.04 * 22)
                    .foregroundStyle(ReefColors.black)

                Text(tutor.species.uppercased())
                    .font(.epilogue(11, weight: .bold))
                    .tracking(0.06 * 11)
                    .foregroundStyle(tintColor)

                Text(tutor.teachingStyle)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray600)
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

                Spacer(minLength: 4)

                // Bottom actions
                HStack(spacing: 10) {
                    Button {
                        onVoicePreview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(isSpeaking ? "Stop" : "Preview Voice")
                        }
                        .frame(minWidth: 100)
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
        .padding(20)
        .background(ReefColors.white)
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
    }
}
