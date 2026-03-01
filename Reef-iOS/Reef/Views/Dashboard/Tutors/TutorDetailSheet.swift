import SwiftUI

struct TutorDetailSheet: View {
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(tintColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(tintColor.opacity(0.3), lineWidth: 2)
                                )

                            Text(tutor.emoji)
                                .font(.system(size: 48))
                        }

                        Text(tutor.name)
                            .font(.epilogue(24, weight: .black))
                            .tracking(-0.04 * 24)
                            .foregroundStyle(ReefColors.black)

                        Text(tutor.species.uppercased())
                            .font(.epilogue(12, weight: .bold))
                            .tracking(0.06 * 12)
                            .foregroundStyle(tintColor)

                        Text(tutor.subject)
                            .font(.epilogue(15, weight: .semiBold))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(ReefColors.gray600)
                    }
                    .padding(.top, 8)

                    // Action buttons
                    HStack(spacing: 12) {
                        // Voice preview
                        Button {
                            onVoicePreview()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .bold))

                                Text(isSpeaking ? "Stop" : "Preview Voice")
                                    .font(.epilogue(14, weight: .bold))
                                    .tracking(-0.04 * 14)
                            }
                            .foregroundStyle(tintColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(tintColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(tintColor.opacity(0.3), lineWidth: 1.5)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(tintColor.opacity(0.2))
                                    .offset(x: 3, y: 3)
                            )
                        }
                        .buttonStyle(.plain)

                        // Select tutor
                        Button {
                            onSelect()
                        } label: {
                            HStack(spacing: 8) {
                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }

                                Text(isActive ? "Active Tutor" : "Select Tutor")
                                    .font(.epilogue(14, weight: .bold))
                                    .tracking(-0.04 * 14)
                            }
                            .foregroundStyle(isActive ? ReefColors.white : ReefColors.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isActive ? tintColor : ReefColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ReefColors.black, lineWidth: 1.5)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ReefColors.black)
                                    .offset(x: 3, y: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Sections
                    VStack(alignment: .leading, spacing: 20) {
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

                        // Fun fact with sparkles
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(tintColor)

                                Text("FUN FACT")
                                    .font(.epilogue(11, weight: .bold))
                                    .tracking(0.06 * 11)
                                    .foregroundStyle(ReefColors.gray400)
                            }

                            Text(tutor.funFact)
                                .font(.epilogue(14, weight: .medium))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.gray600)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ReefColors.gray500)
                            .frame(width: 32, height: 32)
                            .background(ReefColors.gray100)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Section

    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.epilogue(11, weight: .bold))
                .tracking(0.06 * 11)
                .foregroundStyle(ReefColors.gray400)

            Text(content)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
        }
    }
}
