import SwiftUI

// MARK: - Settings Profile Tab

struct SettingsProfileTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    private let profileRepo: ProfileRepository
    let onToast: (String) -> Void

    @State private var displayName: String = ""
    @State private var selectedGrade: String = ""
    @State private var selectedSubjects: Set<String> = []
    @State private var avatarColorIndex: Int = 0
    @State private var dailyGoalMinutes: Int = 30
    @State private var saveTask: Task<Void, Never>?

    // Snapshots of the last-loaded values — saves only fire when something actually changed
    @State private var loadedDisplayName: String = ""
    @State private var loadedGrade: String = ""
    @State private var loadedSubjects: Set<String> = []
    @State private var loadedAvatarColorIndex: Int = 0
    @State private var loadedDailyGoalMinutes: Int = 30

    private let avatarColors = settingsAvatarColors

    init(
        profileRepo: ProfileRepository = SupabaseProfileRepository(),
        onToast: @escaping (String) -> Void
    ) {
        self.profileRepo = profileRepo
        self.onToast = onToast
    }

    var body: some View {
        let colors = theme.colors
        // Single bento card: all cells share one outer border
        VStack(spacing: 0) {
            // Row 1: Profile header (full width)
            profileHeaderRow(colors)
                .padding(metrics.cardPadding)

            Rectangle()
                .fill(colors.divider)
                .frame(height: 1)

            // Row 2: Personal Info | Education
            HStack(alignment: .top, spacing: 0) {
                personalInfoContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle()
                    .fill(colors.divider)
                    .frame(width: 1)

                educationContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.isDarkMode ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.isDarkMode ? ReefColors.Dark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
        .compositingGroup()
        .onAppear { loadFromProfile() }
        .onDisappear { flushSave() }
        .onChange(of: displayName) { scheduleSave() }
        .onChange(of: selectedGrade) { scheduleSave() }
        .onChange(of: selectedSubjects) { scheduleSave() }
        .onChange(of: avatarColorIndex) { scheduleSave() }
        .onChange(of: dailyGoalMinutes) { scheduleSave() }
    }

    // MARK: - Profile Header Row

    private func profileHeaderRow(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 20) {
            profileRing(colors)

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.displayName)
                    .font(.epilogue(18, weight: .black))
                    .tracking(-0.04 * 18)
                    .foregroundStyle(colors.text)

                if let email = auth.profile?.email ?? auth.session?.email {
                    Text(email)
                        .font(.epilogue(13, weight: .medium))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.textSecondary)
                }

                if let createdAt = auth.profile?.createdAt {
                    Text("Member since \(formattedDate(createdAt))")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                        .padding(.top, 2)
                }
            }

            Spacer()

            completionRing(colors)
        }
    }

    private func profileRing(_ colors: ReefThemeColors) -> some View {
        let bgColor = avatarColors.indices.contains(avatarColorIndex)
            ? avatarColors[avatarColorIndex]
            : colors.surface
        return ZStack {
            Circle()
                .fill(bgColor)
                .frame(width: metrics.profileRingSize, height: metrics.profileRingSize)
                .overlay(Circle().strokeBorder(colors.border, lineWidth: 2))

            Text(auth.userInitials)
                .font(.epilogue(metrics.profileRingSize * 0.32, weight: .black))
                .tracking(-0.04 * metrics.profileRingSize * 0.32)
                .foregroundStyle(colors.text)
        }
    }

    private func completionRing(_ colors: ReefThemeColors) -> some View {
        let pct = completionPercentage
        let size: CGFloat = 60
        let stroke: CGFloat = 6
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(colors.subtle, lineWidth: stroke)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(ReefColors.primary, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                    .animation(.easeOut(duration: 0.6), value: pct)

                Text("\(Int(pct * 100))%")
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)
            }

            Text("Complete")
                .font(.epilogue(11, weight: .medium))
                .tracking(-0.04 * 11)
                .foregroundStyle(colors.textMuted)
        }
    }

    private var completionPercentage: CGFloat {
        var score: CGFloat = 0
        let total: CGFloat = 4
        if !(auth.profile?.displayName?.isEmpty ?? true) { score += 1 }
        if !(auth.profile?.email?.isEmpty ?? true) { score += 1 }
        if !(auth.profile?.grade?.isEmpty ?? true) { score += 1 }
        if !(auth.profile?.subjects.isEmpty ?? true) { score += 1 }
        return score / total
    }

    // MARK: - Personal Info Cell

    private func personalInfoContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Personal Info")
                .padding(.bottom, 14)
            nameField(colors)
            SettingsDivider()
            emailField(colors)
            SettingsDivider()
            avatarColorRow(colors)
            SettingsDivider()
            dailyGoalRow(colors)
            SettingsDivider()
            memberIdRow(colors)
        }
    }

    private func avatarColorRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsFieldLabel(title: "Avatar Color")
            HStack(spacing: 10) {
                ForEach(avatarColors.indices, id: \.self) { idx in
                    let isSelected = avatarColorIndex == idx
                    ZStack {
                        Circle()
                            .fill(avatarColors[idx])
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(isSelected ? ReefColors.primary : colors.border, lineWidth: isSelected ? 2.5 : 1.5))
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ReefColors.primary)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { avatarColorIndex = idx }
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                Spacer()
            }
        }
    }

    private func dailyGoalRow(_ colors: ReefThemeColors) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Study Goal")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)
                Text("\(dailyGoalMinutes) min per day")
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            SettingsStepper(value: $dailyGoalMinutes, in: 15...180, step: 15)
        }
    }

    private func memberIdRow(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel(title: "Member ID")
            Text(auth.profile?.id ?? auth.session?.userId ?? "—")
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(colors.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nameField(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsFieldLabel(title: "Display Name")
            TextField("Your name", text: $displayName)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)
                .padding(12)
                .background(colors.input)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(colors.inputBorder, lineWidth: 1.5)
                )
        }
    }

    private func emailField(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsFieldLabel(title: "Email")
            HStack {
                Text(auth.profile?.email ?? auth.session?.email ?? "—")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text("Managed by auth")
                    .font(.epilogue(11, weight: .medium))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(colors.textDisabled)
            }
        }
    }

    // MARK: - Education Cell

    private func educationContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Education")
            gradeSelector(colors)
            SettingsDivider()
            subjectSelector(colors)
        }
    }

    private func gradeSelector(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsFieldLabel(title: "Grade / Year")
            FlowLayout(spacing: 5) {
                ForEach(settingsGrades, id: \.self) { grade in
                    SettingsPill(
                        label: grade,
                        isSelected: selectedGrade == grade
                    ) {
                        selectedGrade = selectedGrade == grade ? "" : grade
                    }
                    .padding(3)
                }
            }
        }
    }

    private func subjectSelector(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SettingsFieldLabel(title: "Subjects")
                Spacer()
                Text("\(selectedSubjects.count) selected")
                    .font(.epilogue(11, weight: .medium))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(colors.textMuted)
            }

            FlowLayout(spacing: 5) {
                ForEach(settingsAllSubjects, id: \.self) { subject in
                    SettingsPill(
                        label: subject,
                        isSelected: selectedSubjects.contains(subject),
                        horizontalPadding: 12
                    ) {
                        if selectedSubjects.contains(subject) {
                            selectedSubjects.remove(subject)
                        } else {
                            selectedSubjects.insert(subject)
                        }
                    }
                    .padding(3)
                }
            }
        }
    }

    // MARK: - Data

    private func loadFromProfile() {
        guard let profile = auth.profile else { return }
        displayName = profile.displayName ?? ""
        selectedGrade = profile.grade ?? ""
        selectedSubjects = Set(profile.subjects)
        avatarColorIndex = profile.settings.avatarColorIndex
        dailyGoalMinutes = profile.settings.dailyGoalMinutes
        // Capture snapshots so onChange can detect real user changes vs initial load
        loadedDisplayName = displayName
        loadedGrade = selectedGrade
        loadedSubjects = selectedSubjects
        loadedAvatarColorIndex = avatarColorIndex
        loadedDailyGoalMinutes = dailyGoalMinutes
    }

    private var hasUnsavedChanges: Bool {
        displayName != loadedDisplayName ||
        selectedGrade != loadedGrade ||
        selectedSubjects != loadedSubjects ||
        avatarColorIndex != loadedAvatarColorIndex ||
        dailyGoalMinutes != loadedDailyGoalMinutes
    }

    private func scheduleSave() {
        guard hasUnsavedChanges else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            await saveProfile()
        }
    }

    private func flushSave() {
        saveTask?.cancel()
        guard hasUnsavedChanges else { return }
        Task { @MainActor in await saveProfile() }
    }

    private func saveProfile() async {
        var settings = auth.profile?.settings ?? UserSettings()
        settings.avatarColorIndex = avatarColorIndex
        settings.dailyGoalMinutes = dailyGoalMinutes

        let update = ProfileUpdate(
            displayName: displayName.isEmpty ? nil : displayName,
            grade: selectedGrade.isEmpty ? nil : selectedGrade,
            subjects: Array(selectedSubjects),
            settings: settings
        )
        do {
            try await profileRepo.upsertProfile(update)
            await auth.completeOnboarding()
            // Advance snapshots so unchanged fields don't re-trigger saves
            loadedDisplayName = displayName
            loadedGrade = selectedGrade
            loadedSubjects = selectedSubjects
            loadedAvatarColorIndex = avatarColorIndex
            loadedDailyGoalMinutes = dailyGoalMinutes
        } catch {
            onToast("Failed to save")
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateFormat = "MMM yyyy"
            return display.string(from: date)
        }
        return dateString
    }
}
