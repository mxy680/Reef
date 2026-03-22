import SwiftUI

// MARK: - Privacy Tab

struct SettingsPrivacyTab: View {
    @Environment(ThemeManager.self) private var theme

    let onToast: (String) -> Void

    @State private var usageAnalytics = true
    @State private var crashReports = true
    @State private var personalizedExperience = false
    @State private var thirdPartySharing = false

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 16) {
            // Row 1: Analytics | Data Sharing
            SettingsRow {
                analyticsCard(dark: dark)
                dataSharingCard(dark: dark)
            }

            // Row 2: Your Data | Privacy Notice
            SettingsRow {
                yourDataCard()
                privacyNoticeCard(dark: dark)
            }
        }
    }

    // MARK: - Analytics

    private func analyticsCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Analytics")

                SettingsToggleRow(label: "Usage Analytics", isOn: $usageAnalytics)
                settingsDescription("Help us improve Reef by sharing anonymous usage data", dark: dark)

                SettingsDivider()

                SettingsToggleRow(label: "Crash Reports", isOn: $crashReports)
                settingsDescription("Automatically send crash reports", dark: dark)
            }
        }
    }

    // MARK: - Data Sharing

    private func dataSharingCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Data Sharing")

                SettingsToggleRow(label: "Personalized Experience", isOn: $personalizedExperience)
                settingsDescription("Use your study patterns to improve recommendations", dark: dark)

                SettingsDivider()

                SettingsToggleRow(label: "Third-Party Sharing", isOn: $thirdPartySharing)
                settingsDescription("Share anonymized data with research partners", dark: dark)
            }
        }
    }

    // MARK: - Your Data

    private func yourDataCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSectionHeader("Your Data")

                Button("Export My Data") {
                    onToast("Export started — you'll receive an email when it's ready")
                }
                .reefCompactStyle(.secondary)

                Button("What We Collect") {}
                    .reefCompactStyle(.secondary)

                Button("Request Data Deletion") {
                    onToast("Request submitted — we'll process it within 30 days")
                }
                .reefCompactStyle(.secondary)
            }
        }
    }

    // MARK: - Privacy Notice

    private func privacyNoticeCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSectionHeader("Privacy Notice")

                Text("Your data is protected by industry-standard security practices.")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                privacyBullet(icon: "lock.shield", text: "End-to-end encryption", dark: dark)
                privacyBullet(icon: "hand.raised", text: "No data sold to advertisers", dark: dark)
                privacyBullet(icon: "server.rack", text: "US-based servers", dark: dark)
                privacyBullet(icon: "trash", text: "30-day deletion guarantee", dark: dark)
            }
        }
    }

    // MARK: - Helpers

    private func settingsDescription(_ text: String, dark: Bool) -> some View {
        Text(text)
            .font(.epilogue(12, weight: .medium))
            .tracking(-0.04 * 12)
            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
            .padding(.top, 4)
    }

    private func privacyBullet(icon: String, text: String, dark: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ReefColors.primary)
                .frame(width: 20)

            Text(text)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
        }
    }
}
