import SwiftUI
import Supabase

// MARK: - Profile Tab

struct SettingsProfileTab: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var theme
    @Environment(\.layoutMetrics) private var metrics

    let onToast: (String) -> Void

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedGrade = ""
    @State private var selectedSubjects: [String] = []
    @State private var educationDirty = false
    @State private var appeared = false

    private let profileManager = ProfileManager()

    var body: some View {
        let dark = theme.isDarkMode
        let profile = authManager.profile
        let completionItems = Self.profileCompletionItems(profile, email: authManager.session?.user.email)
        let completionPct = Double(completionItems.filter(\.done).count) / Double(completionItems.count)

        VStack(spacing: 16) {
            // Row 1: Personal Info | Profile Completion
            SettingsRow {
                personalInfoCard(profile: profile, dark: dark)
                profileCompletionCard(items: completionItems, pct: completionPct, dark: dark)
            }

            // Row 2: Education
            educationCard(dark: dark)
        }
        .onAppear {
            appeared = true
            loadProfile()
        }
    }

    // MARK: - Personal Info

    private func personalInfoCard(profile: Profile?, dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Personal Info")

                SettingsFieldLabel("Name")
                if isEditingName {
                    nameEditor(profile: profile, dark: dark)
                } else {
                    nameDisplay(profile: profile, dark: dark)
                }

                SettingsDivider()

                SettingsFieldLabel("Email")
                Text(authManager.session?.user.email ?? "—")
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                SettingsDivider()

                SettingsFieldLabel("Member Since")
                Text(Self.memberSinceText(profile?.createdAt))
                    .font(.epilogue(15, weight: .semiBold))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
            }
        }
    }

    private func nameEditor(profile: Profile?, dark: Bool) -> some View {
        HStack(spacing: 8) {
            TextField("Your name", text: $editedName)
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
                )

            Button {
                saveName()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ReefColors.primary)
            }

            Button {
                isEditingName = false
                editedName = profile?.displayName ?? ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
            }
        }
    }

    private func nameDisplay(profile: Profile?, dark: Bool) -> some View {
        HStack {
            Text(profile?.displayName ?? "Not set")
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Spacer()

            Button {
                editedName = profile?.displayName ?? ""
                isEditingName = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
            }
        }
    }

    // MARK: - Profile Completion

    private func profileCompletionCard(items: [CompletionItem], pct: Double, dark: Bool) -> some View {
        SettingsCard {
            VStack(spacing: 16) {
                SettingsSectionHeader("Profile Completion")

                ZStack {
                    Circle()
                        .stroke(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100, lineWidth: metrics.profileRingSize * 0.083)

                    Circle()
                        .trim(from: 0, to: appeared ? pct : 0)
                        .stroke(ReefColors.primary, style: StrokeStyle(lineWidth: metrics.profileRingSize * 0.083, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)

                    Text("\(Int(pct * 100))%")
                        .font(.epilogue(22, weight: .bold))
                        .tracking(-0.04 * 22)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                }
                .frame(width: metrics.profileRingSize, height: metrics.profileRingSize)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.label) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(item.done ? ReefColors.primary : (dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400))

                            Text(item.label)
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(item.done ? (dark ? ReefColors.DashboardDark.text : ReefColors.black) : (dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Education

    private func educationCard(dark: Bool) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader("Education")

                SettingsFieldLabel("Grade Level")
                HStack(spacing: 8) {
                    ForEach(settingsGrades, id: \.value) { item in
                        SettingsPill(
                            label: item.label,
                            isSelected: selectedGrade == item.value
                        ) {
                            if selectedGrade != item.value {
                                selectedGrade = item.value
                                educationDirty = true
                            }
                        }
                    }
                }
                .padding(.bottom, 20)

                SettingsFieldLabel("Subjects")
                FlowLayout(spacing: 8) {
                    ForEach(settingsAllSubjects, id: \.self) { subject in
                        SubjectPill(
                            label: subject,
                            isSelected: selectedSubjects.contains(subject)
                        ) {
                            toggleSubject(subject)
                        }
                    }
                }

                if educationDirty {
                    HStack {
                        Spacer()
                        Button("Save Changes") { saveEducation() }
                            .reefCompactStyle(.primary)
                    }
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: educationDirty)
        }
    }

    // MARK: - Actions

    private func loadProfile() {
        guard let profile = authManager.profile else { return }
        editedName = profile.displayName ?? ""
        selectedGrade = profile.grade ?? ""
        selectedSubjects = profile.subjects
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isEditingName = false
        Task {
            try? await profileManager.upsertProfile(fields: [
                "display_name": .string(trimmed),
            ])
            await authManager.completeOnboarding()
            onToast("Name updated")
        }
    }

    private func toggleSubject(_ subject: String) {
        if let idx = selectedSubjects.firstIndex(of: subject) {
            selectedSubjects.remove(at: idx)
        } else {
            selectedSubjects.append(subject)
        }
        educationDirty = true
    }

    private func saveEducation() {
        educationDirty = false
        Task {
            try? await profileManager.upsertProfile(fields: [
                "grade": .string(selectedGrade),
                "subjects": .array(selectedSubjects.map { .string($0) }),
            ])
            await authManager.completeOnboarding()
            onToast("Education updated")
        }
    }

    // MARK: - Helpers

    struct CompletionItem {
        let label: String
        let done: Bool
    }

    static func profileCompletionItems(_ profile: Profile?, email: String?) -> [CompletionItem] {
        [
            CompletionItem(label: "Display name", done: !(profile?.displayName ?? "").isEmpty),
            CompletionItem(label: "Email verified", done: email != nil),
            CompletionItem(label: "Grade level", done: !(profile?.grade ?? "").isEmpty),
            CompletionItem(label: "Subjects selected", done: !(profile?.subjects ?? []).isEmpty),
        ]
    }

    private static let memberSinceISO8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let memberSinceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func memberSinceText(_ dateStr: String?) -> String {
        guard let dateStr else { return "—" }
        guard let date = memberSinceISO8601.date(from: dateStr) else { return "—" }
        return memberSinceDateFormatter.string(from: date)
    }
}
