import SwiftUI

// MARK: - About Tab

struct SettingsAboutTab: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 16) {
            // Row 1: App Info | What's New
            SettingsRow {
                appInfoCard(dark: dark)
                whatsNewCard(dark: dark)
            }

            // Row 2: Support | Social
            SettingsRow {
                supportCard()
                socialCard()
            }

            // Row 3: Legal
            legalCard()
        }
    }

    // MARK: - App Info

    private func appInfoCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("App Info")

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ReefColors.primary)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("R")
                                .font(.epilogue(26, weight: .black))
                                .tracking(-0.04 * 26)
                                .foregroundStyle(ReefColors.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 2)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
                                .offset(x: 3, y: 3)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reef")
                            .font(.epilogue(20, weight: .black))
                            .tracking(-0.04 * 20)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                        Text("1.0.0 (Build 42)")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                    }
                }

                Text("Your AI-powered study companion. Upload documents, generate quizzes, and master any subject.")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                    .padding(.top, 14)

                SettingsDivider()

                HStack(spacing: 24) {
                    infoRow(label: "Platform", value: "iPad", dark: dark)
                    infoRow(label: "Environment", value: "Production", dark: dark)
                }
            }
        }
    }

    // MARK: - What's New

    private func whatsNewCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("What's New")

                Text("v1.0.0 — February 2026")
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                    .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 8) {
                    releaseNote("Document upload & management", dark: dark)
                    releaseNote("Course organization", dark: dark)
                    releaseNote("AI-powered quizzes", dark: dark)
                    releaseNote("Study analytics dashboard", dark: dark)
                }
            }
        }
    }

    // MARK: - Support

    private func supportCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Support")

                SettingsLinkRow(icon: "envelope", label: "Contact Support")
                SettingsLinkRow(icon: "questionmark.circle", label: "Help Center")
                SettingsLinkRow(icon: "ladybug", label: "Report a Bug")
                SettingsLinkRow(icon: "bubble.left", label: "Send Feedback")
            }
        }
    }

    // MARK: - Social

    private func socialCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Social")

                SettingsLinkRow(icon: "at", label: "X / Twitter")
                SettingsLinkRow(icon: "camera", label: "Instagram")
                SettingsLinkRow(icon: "bubble.left.and.bubble.right", label: "Discord Community")
                SettingsLinkRow(icon: "play.rectangle", label: "YouTube")
            }
        }
    }

    // MARK: - Legal

    private func legalCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Legal")

                HStack(spacing: 0) {
                    SettingsLinkRow(icon: "doc.text", label: "Terms of Service")
                        .frame(maxWidth: .infinity)
                    SettingsLinkRow(icon: "hand.raised", label: "Privacy Policy")
                        .frame(maxWidth: .infinity)
                    SettingsLinkRow(icon: "chevron.left.forwardslash.chevron.right", label: "Open Source Licenses")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.epilogue(11, weight: .bold))
                .tracking(0.06 * 11)
                .textCase(.uppercase)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)

            Text(value)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
        }
    }

    private func releaseNote(_ text: String, dark: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ReefColors.primary)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
        }
    }
}
