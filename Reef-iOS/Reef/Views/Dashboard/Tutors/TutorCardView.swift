import SwiftUI

struct TutorCardView: View {
    let tutor: Tutor
    let index: Int
    let isSpeaking: Bool
    let onTap: () -> Void
    let onVoicePreview: () -> Void

    @State private var isPressed = false

    private var tintColor: Color {
        Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Avatar area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tintColor.opacity(0.15))

                    Text(tutor.emoji)
                        .font(.system(size: 64))
                }
                .frame(height: 140)
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(tutor.name)
                        .font(.epilogue(18, weight: .bold))
                        .tracking(-0.04 * 18)
                        .foregroundStyle(ReefColors.black)

                    Text(tutor.species.uppercased())
                        .font(.epilogue(11, weight: .bold))
                        .tracking(0.06 * 11)
                        .foregroundStyle(tintColor)

                    Text(tutor.subject)
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(ReefColors.gray600)

                    Text(tutor.shortBio)
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(ReefColors.gray500)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 10)

                // Voice preview pill
                Button {
                    onVoicePreview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))

                        Text(isSpeaking ? "Stop" : "Preview voice")
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                    }
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(tintColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(tintColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(width: 260, height: 360)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ReefColors.gray500, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ReefColors.gray500)
                    .offset(x: isPressed ? 0 : 4, y: isPressed ? 0 : 4)
            )
            .offset(x: isPressed ? 4 : 0, y: isPressed ? 4 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = false }
                }
        )
        .fadeUp(index: index)
    }
}
