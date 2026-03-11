import SwiftUI

// MARK: - Privacy Tab

extension SettingsView {
    var privacyTab: some View {
        let dark = theme.isDarkMode
        return VStack(spacing: 16) {
            // Row 1: Analytics | Data Sharing
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Analytics")

                        SettingsToggleRow(label: "Usage Analytics", isOn: $usageAnalytics)
                        Text("Help us improve Reef by sharing anonymous usage data")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            .padding(.top, 4)

                        SettingsDivider()

                        SettingsToggleRow(label: "Crash Reports", isOn: $crashReports)
                        Text("Automatically send crash reports")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            .padding(.top, 4)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Data Sharing")

                        SettingsToggleRow(label: "Personalized Experience", isOn: $personalizedExperience)
                        Text("Use your study patterns to improve recommendations")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            .padding(.top, 4)

                        SettingsDivider()

                        SettingsToggleRow(label: "Third-Party Sharing", isOn: $thirdPartySharing)
                        Text("Share anonymized data with research partners")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            .padding(.top, 4)
                    }
                }
            }

            // Row 2: Your Data | Privacy Notice
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader("Your Data")

                        Button("Export My Data") {
                            showToast("Export started — you'll receive an email when it's ready")
                        }
                        .reefCompactStyle(.secondary)

                        Button("What We Collect") {}
                            .reefCompactStyle(.secondary)

                        Button("Request Data Deletion") {
                            showToast("Request submitted — we'll process it within 30 days")
                        }
                        .reefCompactStyle(.secondary)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader("Privacy Notice")

                        Text("Your data is protected by industry-standard security practices.")
                            .font(.epilogue(13, weight: .medium))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                        privacyBullet(icon: "lock.shield", text: "End-to-end encryption")
                        privacyBullet(icon: "hand.raised", text: "No data sold to advertisers")
                        privacyBullet(icon: "server.rack", text: "US-based servers")
                        privacyBullet(icon: "trash", text: "30-day deletion guarantee")
                    }
                }
            }
        }
    }

    func privacyBullet(icon: String, text: String) -> some View {
        let dark = theme.isDarkMode
        return HStack(spacing: 10) {
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
