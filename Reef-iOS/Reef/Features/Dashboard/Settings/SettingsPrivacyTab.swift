import SwiftUI

// MARK: - Settings Privacy Tab

struct SettingsPrivacyTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @State private var analyticsEnabled = true
    @State private var crashReporting = true
    @State private var personalisedContent = false
    @State private var shareWithResearchers = false

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            analyticsSection
            dataSharingSection
            yourDataSection
            privacyNoticeSection
        }
    }

    // MARK: - Analytics

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Analytics")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(
                        label: "Usage Analytics",
                        subtitle: "Help us improve by sharing anonymous usage data",
                        isOn: $analyticsEnabled
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        label: "Crash Reporting",
                        subtitle: "Automatically send crash reports to our team",
                        isOn: $crashReporting
                    )
                }
            }
        }
    }

    // MARK: - Data Sharing

    private var dataSharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Data Sharing")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(
                        label: "Personalised Content",
                        subtitle: "Allow Reef to tailor content based on your study patterns",
                        isOn: $personalisedContent
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        label: "Academic Research",
                        subtitle: "Share anonymised data with education researchers",
                        isOn: $shareWithResearchers
                    )
                }
            }
        }
    }

    // MARK: - Your Data

    private var yourDataSection: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Your Data")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsLinkRow(icon: "arrow.down.circle", label: "Download My Data") {
                        // TODO: trigger data export
                    }

                    SettingsDivider()

                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(ReefColors.destructive)
                            .frame(width: 22)

                        Text("Delete All Study Data")
                            .font(.epilogue(14, weight: .semiBold))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.destructive)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(colors.textDisabled)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // TODO: confirm delete study data
                    }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Privacy Notice

    private var privacyNoticeSection: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Privacy Notice")

            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(privacyBullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(ReefColors.primary)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)

                            Text(bullet)
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

    private let privacyBullets = [
        "We never sell your personal data to third parties.",
        "Your documents are processed securely and never used for model training.",
        "Analytics data is fully anonymised before collection.",
        "You can request deletion of all your data at any time.",
        "We comply with GDPR and CCPA privacy regulations.",
    ]
}
