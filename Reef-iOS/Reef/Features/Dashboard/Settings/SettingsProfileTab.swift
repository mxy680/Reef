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
    @State private var isSaving = false

    init(
        profileRepo: ProfileRepository = SupabaseProfileRepository(),
        onToast: @escaping (String) -> Void
    ) {
        self.profileRepo = profileRepo
        self.onToast = onToast
    }

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            profileHeaderSection(colors)

            HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                personalInfoSection(colors)
                    .frame(maxWidth: .infinity)
                educationSection(colors)
                    .frame(maxWidth: .infinity)
            }

            saveRow(colors)
        }
        .onAppear { loadFromProfile() }
    }

    // MARK: - Profile Header

    private func profileHeaderSection(_ colors: ReefThemeColors) -> some View {
        SettingsCard {
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
    }

    private func profileRing(_ colors: ReefThemeColors) -> some View {
        ZStack {
            Circle()
                .fill(colors.surface)
                .frame(width: metrics.profileRingSize, height: metrics.profileRingSize)
                .overlay(Circle().stroke(colors.border, lineWidth: 2))

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

    // MARK: - Personal Info

    private func personalInfoSection(_ colors: ReefThemeColors) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader(title: "Personal Info")
                    .padding(.bottom, 14)
                nameField(colors)
                SettingsDivider()
                emailField(colors)
            }
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
                        .stroke(colors.inputBorder, lineWidth: 1.5)
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

    // MARK: - Education

    private func educationSection(_ colors: ReefThemeColors) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(title: "Education")
                gradeSelector(colors)
                SettingsDivider()
                subjectSelector(colors)
            }
        }
    }

    private func gradeSelector(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsFieldLabel(title: "Grade / Year")
            FlowLayout(spacing: 8) {
                ForEach(settingsGrades, id: \.self) { grade in
                    SettingsPill(
                        label: grade,
                        isSelected: selectedGrade == grade
                    ) {
                        selectedGrade = selectedGrade == grade ? "" : grade
                    }
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

            FlowLayout(spacing: 8) {
                ForEach(settingsAllSubjects, id: \.self) { subject in
                    SubjectPill(
                        subject: subject,
                        isSelected: selectedSubjects.contains(subject)
                    ) {
                        if selectedSubjects.contains(subject) {
                            selectedSubjects.remove(subject)
                        } else {
                            selectedSubjects.insert(subject)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveRow(_ colors: ReefThemeColors) -> some View {
        HStack {
            Spacer()
            ReefButton("Save Changes", variant: .primary, size: .compact, disabled: isSaving) {
                Task { await saveProfile() }
            }
        }
    }

    // MARK: - Data

    private func loadFromProfile() {
        guard let profile = auth.profile else { return }
        displayName = profile.displayName ?? ""
        selectedGrade = profile.grade ?? ""
        selectedSubjects = Set(profile.subjects)
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        let update = ProfileUpdate(
            displayName: displayName.isEmpty ? nil : displayName,
            grade: selectedGrade.isEmpty ? nil : selectedGrade,
            subjects: Array(selectedSubjects)
        )
        do {
            try await profileRepo.upsertProfile(update)
            await auth.completeOnboarding()
            onToast("Profile saved")
        } catch {
            onToast("Failed to save profile")
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
