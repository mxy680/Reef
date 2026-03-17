import SwiftUI

// MARK: - Settings About Tab

struct SettingsAboutTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics
    @Environment(\.openURL) private var openURL

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            // Row 1: App Info | What's New
            HStack(alignment: .top, spacing: 0) {
                appInfoContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                whatsNewContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 2: Support | Community
            HStack(alignment: .top, spacing: 0) {
                supportContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                communityContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 3: Legal (full width)
            legalContent(colors)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(metrics.cardPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dashboardCard()
    }

    // MARK: - App Info Cell

    private func appInfoContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "App Info")
                .padding(.bottom, 14)
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ReefColors.primary.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "fish.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(ReefColors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reef")
                        .font(.epilogue(20, weight: .black))
                        .tracking(-0.04 * 20)
                        .foregroundStyle(colors.text)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.epilogue(13, weight: .medium))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.textSecondary)

                    Text("Study smarter, not harder")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                        .padding(.top, 2)
                }

                Spacer()
            }
        }
    }

    // MARK: - What's New Cell

    private func whatsNewContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "What's New")
                .padding(.bottom, 14)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(changelogEntries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(entry.color.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: entry.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(entry.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.epilogue(13, weight: .bold))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(colors.text)
                            Text(entry.description)
                                .font(.epilogue(12, weight: .medium))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Support Cell

    private func supportContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Support")
                .padding(.bottom, 14)
            SettingsLinkRow(icon: "envelope", label: "Contact Support") {
                open("mailto:support@studyreef.com")
            }
            SettingsDivider()
            SettingsLinkRow(icon: "questionmark.circle", label: "Help Centre") {
                open("https://studyreef.com/help")
            }
            SettingsDivider()
            SettingsLinkRow(icon: "ant.circle", label: "Report a Bug") {
                open("mailto:bugs@studyreef.com")
            }
        }
    }

    // MARK: - Community Cell

    private func communityContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Community")
                .padding(.bottom, 14)
            SettingsLinkRow(icon: "at", label: "Twitter / X") {
                open("https://x.com/studyreef")
            }
            SettingsDivider()
            SettingsLinkRow(icon: "bubble.left.and.bubble.right", label: "Discord Server") {
                open("https://discord.gg/studyreef")
            }
            SettingsDivider()
            SettingsLinkRow(icon: "star", label: "Rate on App Store") {
                open("itms-apps://itunes.apple.com/app/id000000000?action=write-review")
            }
        }
    }

    // MARK: - Legal Cell

    private func legalContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Legal")
                .padding(.bottom, 14)
            SettingsLinkRow(icon: "doc.text", label: "Terms of Service") {
                open("https://studyreef.com/terms")
            }
            SettingsDivider()
            SettingsLinkRow(icon: "lock.doc", label: "Privacy Policy") {
                open("https://studyreef.com/privacy")
            }
            SettingsDivider()
            HStack {
                Text("© 2025 Reef. All rights reserved.")
                    .font(.epilogue(11, weight: .medium))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(colors.textDisabled)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}

// MARK: - Changelog Entry

private struct ChangelogEntry: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let description: String
}

private let changelogEntries: [ChangelogEntry] = [
    .init(
        icon: "doc.fill",
        color: ReefColors.primary,
        title: "Document Library",
        description: "Upload PDFs and generate AI-powered study materials."
    ),
    .init(
        icon: "chart.bar.fill",
        color: Color(hex: 0x81B29A),
        title: "Study Analytics",
        description: "Track study time, mastery, and session history."
    ),
    .init(
        icon: "sparkles",
        color: ReefColors.abyss,
        title: "AI Tutors (Coming Soon)",
        description: "Subject-specific tutors to guide you through problems."
    ),
]
