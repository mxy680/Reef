import SwiftUI

// MARK: - Settings Privacy Tab

struct SettingsPrivacyTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @State private var analyticsEnabled = true
    @State private var crashReporting = true
    @State private var performanceMonitoring = true
    @State private var sessionRecording = false
    @State private var personalisedContent = false
    @State private var shareWithResearchers = false
    @State private var profileVisibility = true
    @State private var progressBenchmarking = false

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            // Row 1: Analytics | Data Sharing
            HStack(alignment: .top, spacing: 0) {
                analyticsContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                dataSharingContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 2: Your Data | Privacy Notice
            HStack(alignment: .top, spacing: 0) {
                yourDataContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                privacyNoticeContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }

    // MARK: - Analytics Cell

    private func analyticsContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Analytics")
                .padding(.bottom, 14)
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
            SettingsDivider()
            SettingsToggleRow(
                label: "Performance Monitoring",
                subtitle: "Track app performance to identify slow screens",
                isOn: $performanceMonitoring
            )
            SettingsDivider()
            SettingsToggleRow(
                label: "Session Recording",
                subtitle: "Record anonymised sessions to improve UX",
                isOn: $sessionRecording
            )
        }
    }

    // MARK: - Data Sharing Cell

    private func dataSharingContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Data Sharing")
                .padding(.bottom, 14)
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
            SettingsDivider()
            SettingsToggleRow(
                label: "Profile Visibility",
                subtitle: "Let tutors see your grade and selected subjects",
                isOn: $profileVisibility
            )
            SettingsDivider()
            SettingsToggleRow(
                label: "Progress Benchmarking",
                subtitle: "Compare your progress anonymously with peers",
                isOn: $progressBenchmarking
            )
        }
    }

    // MARK: - Your Data Cell

    private func yourDataContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Your Data")
                .padding(.bottom, 14)
            SettingsLinkRow(icon: "arrow.down.circle", label: "Download My Data") {}
            SettingsDivider()
            SettingsLinkRow(icon: "arrow.triangle.2.circlepath", label: "Sync Now") {}
            SettingsDivider()
            SettingsLinkRow(icon: "internaldrive", label: "Clear Cache") {}
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
            .onTapGesture {}
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Privacy Notice Cell

    private func privacyNoticeContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Privacy Notice")
                .padding(.bottom, 14)
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

    private let privacyBullets = [
        "We never sell your personal data to third parties.",
        "Your documents are processed securely and never used for model training.",
        "Analytics data is fully anonymised before collection.",
        "You can request deletion of all your data at any time.",
        "We comply with GDPR and CCPA privacy regulations.",
    ]
}
