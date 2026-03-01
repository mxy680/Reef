import SwiftUI

struct TutorCardView: View {
    let tutor: Tutor
    let index: Int
    let isSpeaking: Bool
    let isActive: Bool
    let onTap: () -> Void
    let onVoicePreview: () -> Void
    let onSelect: () -> Void

    @State private var isPressed = false

    private var tintColor: Color {
        Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
    }

    private var borderColor: Color {
        isActive ? tintColor : ReefColors.gray500
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Avatar area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tintColor.opacity(isActive ? 0.2 : 0.1))

                    Text(tutor.emoji)
                        .font(.system(size: 56))
                }
                .frame(height: 130)
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(tutor.name)
                            .font(.epilogue(18, weight: .bold))
                            .tracking(-0.04 * 18)
                            .foregroundStyle(ReefColors.black)

                        Spacer()

                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(tintColor)
                        }
                    }

                    Text(tutor.species.uppercased())
                        .font(.epilogue(10, weight: .bold))
                        .tracking(0.06 * 10)
                        .foregroundStyle(tintColor)

                    Text(tutor.subject)
                        .font(.epilogue(12, weight: .semiBold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(ReefColors.gray600)

                    Text(tutor.shortBio)
                        .font(.epilogue(11, weight: .medium))
                        .tracking(-0.04 * 11)
                        .foregroundStyle(ReefColors.gray500)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer(minLength: 8)

                // Bottom actions
                HStack(spacing: 8) {
                    // Voice preview pill
                    Button {
                        onVoicePreview()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 9, weight: .bold))

                            Text(isSpeaking ? "Stop" : "Voice")
                                .font(.epilogue(11, weight: .bold))
                                .tracking(-0.04 * 11)
                        }
                        .foregroundStyle(tintColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(tintColor.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(tintColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Select button
                    Button {
                        onSelect()
                    } label: {
                        HStack(spacing: 5) {
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                            }

                            Text(isActive ? "Active" : "Select")
                                .font(.epilogue(11, weight: .bold))
                                .tracking(-0.04 * 11)
                        }
                        .foregroundStyle(isActive ? ReefColors.white : tintColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isActive ? tintColor : tintColor.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isActive ? tintColor : tintColor.opacity(0.25), lineWidth: isActive ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(width: 240, height: 380)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: isActive ? 2.5 : 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(borderColor)
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
