import SwiftUI

// MARK: - Shared Dialog Card Style

private struct DialogCard: ViewModifier {
    let colors: ReefThemeColors

    func body(content: Content) -> some View {
        content
            .font(.epilogue(14, weight: .semiBold))
            .tracking(-0.04 * 14)
            .lineSpacing(3)
            .foregroundStyle(colors.text)
            .padding(16)
            .frame(maxWidth: 340, alignment: .leading)
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.border, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 14).fill(colors.shadow).offset(x: 3, y: 3))
    }
}

private extension View {
    func dialogCardStyle(colors: ReefThemeColors) -> some View {
        modifier(DialogCard(colors: colors))
    }
}

private struct DialogContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            content()
        }
        .padding(.leading, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }
}

// MARK: - Voice Choice Dialog

struct WalkthroughVoiceChoiceDialog: View {
    @Environment(ReefTheme.self) private var theme
    let onVoiceOn: () -> Void
    let onVoiceOff: () -> Void

    var body: some View {
        let colors = theme.colors
        DialogContainer {
            Text("Before we start — do you want me to talk out loud, or keep it text-only?")
                .dialogCardStyle(colors: colors)

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: onVoiceOn) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                        Text("Voice on")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(-0.04 * 11)
                    }
                }

                ReefButton(.secondary, size: .compact, action: onVoiceOff) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 10))
                        Text("Text only")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(-0.04 * 11)
                    }
                }
            }
        }
    }
}

// MARK: - Experience Dialog

struct WalkthroughExperienceDialog: View {
    @Environment(ReefTheme.self) private var theme
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        let colors = theme.colors
        DialogContainer {
            Text("Have you used a note-taking app before? GoodNotes, Notability, OneNote — anything like that?")
                .dialogCardStyle(colors: colors)

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: onYes) {
                    Text("Yeah")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: onNo) {
                    Text("Nope, first time")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
    }
}

// MARK: - Skip Tools Dialog

struct WalkthroughSkipToolsDialog: View {
    @Environment(ReefTheme.self) private var theme
    let onSkip: () -> Void
    let onShowAll: () -> Void

    var body: some View {
        let colors = theme.colors
        DialogContainer {
            Text("Nice — then you already know the basics. Want to skip the drawing tools tutorial and jump straight to the AI tutor?")
                .dialogCardStyle(colors: colors)

            HStack(spacing: 8) {
                ReefButton(.primary, size: .compact, action: onSkip) {
                    Text("Skip to tutor")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }

                ReefButton(.secondary, size: .compact, action: onShowAll) {
                    Text("Show me everything")
                        .font(.epilogue(11, weight: .bold))
                        .tracking(-0.04 * 11)
                }
            }
        }
    }
}

// MARK: - Intro (Pre) Dialog

struct WalkthroughIntroDialog: View {
    @Environment(ReefTheme.self) private var theme
    let introText: String
    let introReady: Bool
    let onLetsGo: () -> Void

    var body: some View {
        let colors = theme.colors
        DialogContainer {
            Text(introText)
                .dialogCardStyle(colors: colors)

            ReefButton(.primary, size: .compact, action: onLetsGo) {
                Text("Let's go")
                    .font(.epilogue(11, weight: .bold))
                    .tracking(-0.04 * 11)
            }
            .opacity(introReady ? 1 : 0.4)
            .disabled(!introReady)
        }
    }
}
