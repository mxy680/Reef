import SwiftUI

struct TutorDetailPopup: View {
    let tutor: Tutor
    let isSpeaking: Bool
    let isActive: Bool
    let onVoicePreview: () -> Void
    let onSelect: () -> Void
    let onClose: () -> Void

    private var tintColor: Color {
        Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { onClose() }

            // Popup card
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ReefColors.gray500)
                            .frame(width: 28, height: 28)
                            .background(ReefColors.gray100)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Avatar + header
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(tintColor.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(tintColor.opacity(0.3), lineWidth: 2)
                                    )

                                Text(tutor.emoji)
                                    .font(.system(size: 40))
                            }

                            Text(tutor.name)
                                .font(.epilogue(22, weight: .black))
                                .tracking(-0.04 * 22)
                                .foregroundStyle(ReefColors.black)

                            Text(tutor.species.uppercased())
                                .font(.epilogue(11, weight: .bold))
                                .tracking(0.06 * 11)
                                .foregroundStyle(tintColor)
                        }

                        // Action buttons
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
                                onSelect()
                            } label: {
                                HStack(spacing: 6) {
                                    if isActive {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    Text(isActive ? "Active" : "Select Tutor")
                                }
                            }
                            .reefCompactStyle(isActive ? .primary : .secondary)
                        }

                        // Info sections
                        VStack(alignment: .leading, spacing: 16) {
                            sectionView(title: "ABOUT", content: tutor.shortBio)

                            Rectangle()
                                .fill(ReefColors.gray100)
                                .frame(height: 1)

                            sectionView(title: "TEACHING STYLE", content: tutor.teachingStyle)

                            Rectangle()
                                .fill(ReefColors.gray100)
                                .frame(height: 1)

                            sectionView(title: "VOICE", content: tutor.voiceDescription)

                            Rectangle()
                                .fill(ReefColors.gray100)
                                .frame(height: 1)

                            // Fun fact
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(tintColor)

                                    Text("FUN FACT")
                                        .font(.epilogue(11, weight: .bold))
                                        .tracking(0.06 * 11)
                                        .foregroundStyle(ReefColors.gray400)
                                }

                                Text(tutor.funFact)
                                    .font(.epilogue(13, weight: .medium))
                                    .tracking(-0.04 * 13)
                                    .foregroundStyle(ReefColors.gray600)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ReefColors.black, lineWidth: 1.5)
            )
            .frame(maxWidth: 420, maxHeight: 500)
            .padding(32)
        }
    }

    // MARK: - Section

    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.epilogue(11, weight: .bold))
                .tracking(0.06 * 11)
                .foregroundStyle(ReefColors.gray400)

            Text(content)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
        }
    }
}
