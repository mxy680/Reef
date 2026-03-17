import SwiftUI

// MARK: - Settings Preferences Tab

struct SettingsPreferencesTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    // Appearance
    @State private var selectedThemeColor: Color = ReefColors.primary

    // Notifications
    @State private var studyReminders = true
    @State private var weeklyDigest = true
    @State private var newFeatures = false

    // Study Preferences
    @State private var difficultyLevel = "Medium"
    @State private var questionCount = 10
    @State private var timerEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            appearanceSection
            notificationsSection
            studyPreferencesSection
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Appearance")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    darkModeRow
                    SettingsDivider()
                    themeColorRow
                }
            }
        }
    }

    @ViewBuilder
    private var darkModeRow: some View {
        @Bindable var bindableTheme = theme
        SettingsToggleRow(
            label: "Dark Mode",
            subtitle: "Switch between light and dark appearance",
            isOn: $bindableTheme.isDarkMode
        )
    }

    private var themeColorRow: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 10) {
            SettingsFieldLabel(title: "Accent Color")
            HStack(spacing: 12) {
                ForEach(Array(settingsThemeColors.enumerated()), id: \.offset) { _, color in
                    let isSelected = selectedThemeColor == color
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(
                                isSelected ? colors.border : Color.clear,
                                lineWidth: 2
                            )
                        )
                        .overlay(
                            isSelected
                                ? Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(ReefColors.white)
                                : nil
                        )
                        .contentShape(Circle())
                        .onTapGesture { selectedThemeColor = color }
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                Spacer()
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Notifications")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(
                        label: "Study Reminders",
                        subtitle: "Daily nudges to keep your streak alive",
                        isOn: $studyReminders
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        label: "Weekly Digest",
                        subtitle: "A summary of your progress each week",
                        isOn: $weeklyDigest
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        label: "New Features",
                        subtitle: "Hear about updates and improvements",
                        isOn: $newFeatures
                    )
                }
            }
        }
    }

    // MARK: - Study Preferences

    private var studyPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Study Preferences")

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    difficultyRow
                    SettingsDivider()
                    questionCountRow
                    SettingsDivider()
                    timerRow
                }
            }
        }
    }

    private var difficultyRow: some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Difficulty Level")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                Spacer()
            }
            SettingsSegmentedControl(
                options: ["Easy", "Medium", "Hard"],
                selection: $difficultyLevel
            )
        }
    }

    private var questionCountRow: some View {
        let colors = theme.colors
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Questions per Session")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)

                Text("How many questions to generate")
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            SettingsStepper(value: $questionCount, in: 5...30, step: 5)
        }
    }

    private var timerRow: some View {
        SettingsToggleRow(
            label: "Study Timer",
            subtitle: "Show a timer during quiz sessions",
            isOn: $timerEnabled
        )
    }
}
