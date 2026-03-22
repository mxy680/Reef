import SwiftUI

// MARK: - Preferences Tab

struct SettingsPreferencesTab: View {
    @Environment(ThemeManager.self) private var theme

    @State private var selectedTheme = "#5B9EAD"
    @State private var emailNotifications = true
    @State private var studyReminders = false
    @State private var weeklyDigest = true
    @State private var focusWeakAreas = true
    @State private var quizDifficulty = "medium"
    @State private var questionCount = 10
    @State private var quizTimer = "off"

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 16) {
            // Row 1: Appearance | Notifications
            SettingsRow {
                appearanceCard(dark: dark)
                notificationsCard()
            }

            // Row 2: Study Preferences
            studyPreferencesCard()
        }
    }

    // MARK: - Appearance

    private func appearanceCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Appearance")

                SettingsToggleRow(
                    label: "Dark Mode",
                    isOn: Binding(
                        get: { theme.isDarkMode },
                        set: { theme.isDarkMode = $0 }
                    )
                )

                SettingsDivider()

                SettingsFieldLabel("Theme Color")
                HStack(spacing: 12) {
                    ForEach(settingsThemeColors, id: \.hex) { item in
                        Circle()
                            .fill(item.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: selectedTheme == item.hex ? 2.5 : 0)
                            )
                            .shadow(color: selectedTheme == item.hex ? (dark ? ReefColors.DashboardDark.shadow : ReefColors.black).opacity(0.3) : .clear, radius: 0, x: 2, y: 2)
                            .contentShape(Circle())
                            .onTapGesture { selectedTheme = item.hex }
                    }
                }
            }
        }
    }

    // MARK: - Notifications

    private func notificationsCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Notifications")

                SettingsToggleRow(label: "Email Notifications", isOn: $emailNotifications)
                SettingsDivider()
                SettingsToggleRow(label: "Study Reminders", isOn: $studyReminders)
                SettingsDivider()
                SettingsToggleRow(label: "Weekly Digest", isOn: $weeklyDigest)
            }
        }
    }

    // MARK: - Study Preferences

    private func studyPreferencesCard() -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Study Preferences")

                HStack(alignment: .top, spacing: 32) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleRow(label: "Focus on Weak Areas", isOn: $focusWeakAreas)
                        SettingsDivider()
                        SettingsFieldLabel("Default Quiz Difficulty")
                        SettingsSegmentedControl(
                            options: ["easy", "medium", "hard"],
                            labels: ["Easy", "Medium", "Hard"],
                            selection: $quizDifficulty
                        )
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 0) {
                        SettingsFieldLabel("Default Question Count")
                        SettingsStepper(value: $questionCount, range: 5...50, step: 5)
                            .padding(.bottom, 20)

                        SettingsFieldLabel("Quiz Timer")
                        SettingsSegmentedControl(
                            options: ["off", "relaxed", "strict"],
                            labels: ["Off", "Relaxed", "Strict"],
                            selection: $quizTimer
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
