import SwiftUI

// MARK: - Settings Preferences Tab

struct SettingsPreferencesTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    private let profileRepo: ProfileRepository
    let onToast: (String) -> Void

    // Appearance (dark mode is owned by ReefTheme, not persisted here)
    @State private var selectedThemeColorIndex: Int = 0
    @State private var compactMode = false
    @State private var textScale = "Standard"

    // Notifications
    @State private var studyReminders = true
    @State private var weeklyDigest = true
    @State private var newFeatures = false
    @State private var achievementAlerts = true
    @State private var reminderTime = "Evening"

    // Study Preferences
    @State private var difficultyLevel = "Medium"
    @State private var questionCount = 10
    @State private var timerEnabled = true
    @State private var autoAdvance = false
    @State private var shuffleQuestions = true

    @State private var saveTask: Task<Void, Never>?
    @State private var loadedSettings: UserSettings = UserSettings()

    init(
        profileRepo: ProfileRepository = SupabaseProfileRepository(),
        onToast: @escaping (String) -> Void
    ) {
        self.profileRepo = profileRepo
        self.onToast = onToast
    }

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            // Row 1: Appearance (full width)
            appearanceContent(colors)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(metrics.cardPadding)

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 2: Notifications | Study Preferences
            HStack(alignment: .top, spacing: 0) {
                notificationsContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                studyPreferencesContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
        .onAppear { loadSettings() }
        .onDisappear { flushSave() }
        .onChange(of: selectedThemeColorIndex) { scheduleSave() }
        .onChange(of: compactMode) { scheduleSave() }
        .onChange(of: textScale) { scheduleSave() }
        .onChange(of: studyReminders) { scheduleSave() }
        .onChange(of: weeklyDigest) { scheduleSave() }
        .onChange(of: newFeatures) { scheduleSave() }
        .onChange(of: achievementAlerts) { scheduleSave() }
        .onChange(of: reminderTime) { scheduleSave() }
        .onChange(of: difficultyLevel) { scheduleSave() }
        .onChange(of: questionCount) { scheduleSave() }
        .onChange(of: timerEnabled) { scheduleSave() }
        .onChange(of: autoAdvance) { scheduleSave() }
        .onChange(of: shuffleQuestions) { scheduleSave() }
    }

    // MARK: - Data

    private var currentSettings: UserSettings {
        var s = auth.profile?.settings ?? UserSettings()
        s.themeColorIndex = selectedThemeColorIndex
        s.compactMode = compactMode
        s.textScale = textScale
        s.studyReminders = studyReminders
        s.weeklyDigest = weeklyDigest
        s.newFeatures = newFeatures
        s.achievementAlerts = achievementAlerts
        s.reminderTime = reminderTime
        s.difficultyLevel = difficultyLevel
        s.questionCount = questionCount
        s.timerEnabled = timerEnabled
        s.autoAdvance = autoAdvance
        s.shuffleQuestions = shuffleQuestions
        return s
    }

    private var hasUnsavedChanges: Bool {
        let s = loadedSettings
        return selectedThemeColorIndex != s.themeColorIndex ||
            compactMode != s.compactMode ||
            textScale != s.textScale ||
            studyReminders != s.studyReminders ||
            weeklyDigest != s.weeklyDigest ||
            newFeatures != s.newFeatures ||
            achievementAlerts != s.achievementAlerts ||
            reminderTime != s.reminderTime ||
            difficultyLevel != s.difficultyLevel ||
            questionCount != s.questionCount ||
            timerEnabled != s.timerEnabled ||
            autoAdvance != s.autoAdvance ||
            shuffleQuestions != s.shuffleQuestions
    }

    private func loadSettings() {
        let s = auth.profile?.settings ?? UserSettings()
        selectedThemeColorIndex = s.themeColorIndex
        compactMode = s.compactMode
        textScale = s.textScale
        studyReminders = s.studyReminders
        weeklyDigest = s.weeklyDigest
        newFeatures = s.newFeatures
        achievementAlerts = s.achievementAlerts
        reminderTime = s.reminderTime
        difficultyLevel = s.difficultyLevel
        questionCount = s.questionCount
        timerEnabled = s.timerEnabled
        autoAdvance = s.autoAdvance
        shuffleQuestions = s.shuffleQuestions
        loadedSettings = s
    }

    private func flushSave() {
        saveTask?.cancel()
        guard hasUnsavedChanges else { return }
        Task { @MainActor in await saveSettings() }
    }

    private func scheduleSave() {
        guard hasUnsavedChanges else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            await saveSettings()
        }
    }

    private func saveSettings() async {
        let settings = currentSettings
        let update = ProfileUpdate(settings: settings)
        do {
            try await profileRepo.upsertProfile(update)
            await auth.completeOnboarding()
            loadedSettings = settings
        } catch {
            onToast("Failed to save")
        }
    }

    // MARK: - Appearance Cell

    private func appearanceContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Appearance")
                .padding(.bottom, 14)
            darkModeRow
            SettingsDivider()
            themeColorRow(colors)
            SettingsDivider()
            textScaleRow(colors)
            SettingsDivider()
            SettingsToggleRow(
                label: "Compact Mode",
                subtitle: "Reduce spacing for more content on screen",
                isOn: $compactMode
            )
        }
    }

    private func textScaleRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Text Size")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                Spacer()
            }
            SettingsSegmentedControl(
                options: ["Small", "Standard", "Large"],
                selection: $textScale
            )
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

    private func themeColorRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsFieldLabel(title: "Accent Color")
            HStack(spacing: 12) {
                ForEach(settingsThemeColors.indices, id: \.self) { idx in
                    let isSelected = selectedThemeColorIndex == idx
                    Circle()
                        .fill(settingsThemeColors[idx])
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
                        .onTapGesture { selectedThemeColorIndex = idx }
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                Spacer()
            }
        }
    }

    // MARK: - Notifications Cell

    private func notificationsContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Notifications")
                .padding(.bottom, 14)
            SettingsToggleRow(
                label: "Study Reminders",
                subtitle: "Daily nudges to keep your streak alive",
                isOn: $studyReminders
            )
            SettingsDivider()
            reminderTimeRow(colors)
            SettingsDivider()
            SettingsToggleRow(
                label: "Achievement Alerts",
                subtitle: "Celebrate streaks and milestones",
                isOn: $achievementAlerts
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

    private func reminderTimeRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reminder Time")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                Spacer()
            }
            SettingsSegmentedControl(
                options: ["Morning", "Afternoon", "Evening"],
                selection: $reminderTime
            )
        }
    }

    // MARK: - Study Preferences Cell

    private func studyPreferencesContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Study Preferences")
                .padding(.bottom, 14)
            difficultyRow(colors)
            SettingsDivider()
            questionCountRow(colors)
            SettingsDivider()
            timerRow
            SettingsDivider()
            SettingsToggleRow(
                label: "Auto-Advance",
                subtitle: "Move to next question automatically after answering",
                isOn: $autoAdvance
            )
            SettingsDivider()
            SettingsToggleRow(
                label: "Shuffle Questions",
                subtitle: "Randomise question order each session",
                isOn: $shuffleQuestions
            )
        }
    }

    private func difficultyRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private func questionCountRow(_ colors: ReefThemeColors) -> some View {
        HStack {
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
