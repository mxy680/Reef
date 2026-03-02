import SwiftUI
import Supabase

// MARK: - Settings Tab Enum

private enum SettingsTab: String, CaseIterable {
    case profile, preferences, privacy, about, account

    var label: String {
        switch self {
        case .profile: "Profile"
        case .preferences: "Preferences"
        case .privacy: "Privacy"
        case .about: "About"
        case .account: "Account"
        }
    }

    var icon: String {
        switch self {
        case .profile: "person"
        case .preferences: "slider.horizontal.3"
        case .privacy: "lock"
        case .about: "info.circle"
        case .account: "gearshape"
        }
    }
}

// MARK: - Constants

private let grades: [(value: String, label: String)] = [
    ("middle_school", "Middle School"),
    ("high_school", "High School"),
    ("college", "College"),
    ("graduate", "Graduate"),
    ("other", "Other"),
]

private let allSubjects = [
    "Algebra", "Geometry", "Precalculus", "Calculus", "Statistics",
    "Linear Algebra", "Trigonometry", "Differential Equations",
    "Physics", "Chemistry", "Biology", "Computer Science",
    "Economics", "Engineering", "Accounting",
]

private let themeColors: [(color: Color, hex: String)] = [
    (Color(hex: 0x5B9EAD), "#5B9EAD"),
    (Color(hex: 0xE07A5F), "#E07A5F"),
    (Color(hex: 0x81B29A), "#81B29A"),
    (Color(hex: 0xF2CC8F), "#F2CC8F"),
    (Color(hex: 0x3D405B), "#3D405B"),
    (Color(hex: 0xA78BFA), "#A78BFA"),
]

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var activeTab: SettingsTab = .profile
    @State private var appeared = false

    // Profile editing state
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedGrade = ""
    @State private var selectedSubjects: [String] = []
    @State private var educationDirty = false

    // Preferences state (local only, matching web)
    @State private var darkMode = false
    @State private var selectedTheme = "#5B9EAD"
    @State private var emailNotifications = true
    @State private var studyReminders = false
    @State private var weeklyDigest = true
    @State private var focusWeakAreas = true
    @State private var quizDifficulty = "medium"
    @State private var questionCount = 10
    @State private var quizTimer = "off"

    // Privacy state (local only)
    @State private var usageAnalytics = true
    @State private var crashReports = true
    @State private var personalizedExperience = false
    @State private var thirdPartySharing = false

    // Toast
    @State private var toastMessage: String?

    // Delete confirmation
    @State private var showDeleteConfirm = false

    private let profileManager = ProfileManager()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                tabBar
                tabContent
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
        .overlay(alignment: .bottomTrailing) { toastOverlay }
        .onAppear {
            appeared = true
            loadProfile()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Text("Settings")
            .font(.epilogue(24, weight: .black))
            .tracking(-0.04 * 24)
            .foregroundStyle(ReefColors.black)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(0.1), value: appeared)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SettingsTabButton(
                    tab: tab,
                    isActive: activeTab == tab,
                    action: { activeTab = tab }
                )
            }
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch activeTab {
            case .profile: profileTab
            case .preferences: preferencesTab
            case .privacy: privacyTab
            case .about: aboutTab
            case .account: accountTab
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.3).delay(0.2), value: appeared)
    }

    // MARK: - Load Profile

    private func loadProfile() {
        guard let profile = authManager.profile else { return }
        editedName = profile.displayName ?? ""
        selectedGrade = profile.grade ?? ""
        selectedSubjects = profile.subjects
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if toastMessage == message { toastMessage = nil }
        }
    }

    private var toastOverlay: some View {
        Group {
            if let message = toastMessage {
                Text(message)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ReefColors.black)
                    .clipShape(Capsule())
                    .padding(24)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: toastMessage != nil)
    }
}

// MARK: - Tab Button

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isActive: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
            Text(tab.label)
                .font(.epilogue(13, weight: .bold))
                .tracking(-0.04 * 13)
        }
        .foregroundStyle(isActive ? ReefColors.white : ReefColors.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? ReefColors.primary : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.black)
                .offset(
                    x: isPressed ? 0 : 3,
                    y: isPressed ? 0 : 3
                )
        )
        .offset(
            x: isPressed ? 3 : 0,
            y: isPressed ? 3 : 0
        )
        .animation(.spring(duration: 0.2, bounce: 0.1), value: isPressed)
        .animation(.spring(duration: 0.2, bounce: 0.1), value: isActive)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: ─── Profile Tab ───────────────────────────────────

extension SettingsView {
    private var profileTab: some View {
        let profile = authManager.profile
        let completionItems = profileCompletionItems(profile)
        let completionPct = Double(completionItems.filter(\.done).count) / Double(completionItems.count)

        return VStack(spacing: 16) {
            // Row 1: Personal Info | Profile Completion
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Personal Info")

                        SettingsFieldLabel("Name")
                        if isEditingName {
                            HStack(spacing: 8) {
                                TextField("Your name", text: $editedName)
                                    .font(.epilogue(15, weight: .medium))
                                    .tracking(-0.04 * 15)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(ReefColors.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(ReefColors.gray400, lineWidth: 1.5)
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
                                        .foregroundStyle(ReefColors.gray500)
                                }
                            }
                        } else {
                            HStack {
                                Text(profile?.displayName ?? "Not set")
                                    .font(.epilogue(15, weight: .semiBold))
                                    .tracking(-0.04 * 15)
                                    .foregroundStyle(ReefColors.black)

                                Spacer()

                                Button {
                                    editedName = profile?.displayName ?? ""
                                    isEditingName = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ReefColors.gray500)
                                }
                            }
                        }

                        SettingsDivider()

                        SettingsFieldLabel("Email")
                        Text(authManager.session?.user.email ?? "—")
                            .font(.epilogue(15, weight: .semiBold))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(ReefColors.black)

                        SettingsDivider()

                        SettingsFieldLabel("Member Since")
                        Text(memberSinceText(profile?.createdAt))
                            .font(.epilogue(15, weight: .semiBold))
                            .tracking(-0.04 * 15)
                            .foregroundStyle(ReefColors.black)
                    }
                }

                SettingsCard {
                    VStack(spacing: 16) {
                        SettingsSectionHeader("Profile Completion")

                        ZStack {
                            Circle()
                                .stroke(ReefColors.gray100, lineWidth: 8)

                            Circle()
                                .trim(from: 0, to: appeared ? completionPct : 0)
                                .stroke(ReefColors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)

                            Text("\(Int(completionPct * 100))%")
                                .font(.epilogue(22, weight: .bold))
                                .tracking(-0.04 * 22)
                                .foregroundStyle(ReefColors.black)
                        }
                        .frame(width: 96, height: 96)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(completionItems, id: \.label) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(item.done ? ReefColors.primary : ReefColors.gray400)

                                    Text(item.label)
                                        .font(.epilogue(13, weight: .medium))
                                        .tracking(-0.04 * 13)
                                        .foregroundStyle(item.done ? ReefColors.black : ReefColors.gray500)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // Row 2: Education (full width)
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader("Education")

                    SettingsFieldLabel("Grade Level")
                    HStack(spacing: 8) {
                        ForEach(grades, id: \.value) { item in
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
                        ForEach(allSubjects, id: \.self) { subject in
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
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isEditingName = false
        Task {
            try? await profileManager.upsertProfile(fields: [
                "display_name": .string(trimmed)
            ])
            await authManager.completeOnboarding()
            showToast("Name updated")
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
                "subjects": .array(selectedSubjects.map { .string($0) })
            ])
            await authManager.completeOnboarding()
            showToast("Education updated")
        }
    }

    private struct CompletionItem {
        let label: String
        let done: Bool
    }

    private func profileCompletionItems(_ profile: Profile?) -> [CompletionItem] {
        [
            CompletionItem(label: "Display name", done: !(profile?.displayName ?? "").isEmpty),
            CompletionItem(label: "Email verified", done: authManager.session?.user.email != nil),
            CompletionItem(label: "Grade level", done: !(profile?.grade ?? "").isEmpty),
            CompletionItem(label: "Subjects selected", done: !(profile?.subjects ?? []).isEmpty),
        ]
    }

    private func memberSinceText(_ dateStr: String?) -> String {
        guard let dateStr else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date)
    }
}

// MARK: ─── Preferences Tab ──────────────────────────────

extension SettingsView {
    private var preferencesTab: some View {
        VStack(spacing: 16) {
            // Row 1: Appearance | Notifications
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Appearance")

                        SettingsToggleRow(
                            label: "Dark Mode",
                            isOn: $darkMode
                        )

                        SettingsDivider()

                        SettingsFieldLabel("Theme Color")
                        HStack(spacing: 12) {
                            ForEach(themeColors, id: \.hex) { item in
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(ReefColors.black, lineWidth: selectedTheme == item.hex ? 2.5 : 0)
                                    )
                                    .shadow(color: selectedTheme == item.hex ? ReefColors.black.opacity(0.3) : .clear, radius: 0, x: 2, y: 2)
                                    .contentShape(Circle())
                                    .onTapGesture { selectedTheme = item.hex }
                            }
                        }
                    }
                }

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

            // Row 2: Study Preferences (full width)
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
}

// MARK: ─── Privacy Tab ──────────────────────────────────

extension SettingsView {
    private var privacyTab: some View {
        VStack(spacing: 16) {
            // Row 1: Analytics | Data Sharing
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Analytics")

                        SettingsToggleRow(label: "Usage Analytics", isOn: $usageAnalytics)
                        Text("Help us improve Reef by sharing anonymous usage data")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(ReefColors.gray500)
                            .padding(.top, 4)

                        SettingsDivider()

                        SettingsToggleRow(label: "Crash Reports", isOn: $crashReports)
                        Text("Automatically send crash reports")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(ReefColors.gray500)
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
                            .foregroundStyle(ReefColors.gray500)
                            .padding(.top, 4)

                        SettingsDivider()

                        SettingsToggleRow(label: "Third-Party Sharing", isOn: $thirdPartySharing)
                        Text("Share anonymized data with research partners")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(ReefColors.gray500)
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
                            .foregroundStyle(ReefColors.gray600)

                        privacyBullet(icon: "lock.shield", text: "End-to-end encryption")
                        privacyBullet(icon: "hand.raised", text: "No data sold to advertisers")
                        privacyBullet(icon: "server.rack", text: "US-based servers")
                        privacyBullet(icon: "trash", text: "30-day deletion guarantee")
                    }
                }
            }
        }
    }

    private func privacyBullet(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ReefColors.primary)
                .frame(width: 20)

            Text(text)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.black)
        }
    }
}

// MARK: ─── About Tab ────────────────────────────────────

extension SettingsView {
    private var aboutTab: some View {
        VStack(spacing: 16) {
            // Row 1: App Info | What's New
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("App Info")

                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ReefColors.primary)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text("R")
                                        .font(.epilogue(26, weight: .black))
                                        .tracking(-0.04 * 26)
                                        .foregroundStyle(ReefColors.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ReefColors.black, lineWidth: 2)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ReefColors.black)
                                        .offset(x: 3, y: 3)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reef")
                                    .font(.epilogue(20, weight: .black))
                                    .tracking(-0.04 * 20)
                                    .foregroundStyle(ReefColors.black)

                                Text("1.0.0 (Build 42)")
                                    .font(.epilogue(12, weight: .medium))
                                    .tracking(-0.04 * 12)
                                    .foregroundStyle(ReefColors.gray500)
                            }
                        }

                        Text("Your AI-powered study companion. Upload documents, generate quizzes, and master any subject.")
                            .font(.epilogue(13, weight: .medium))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(ReefColors.gray600)
                            .padding(.top, 14)

                        SettingsDivider()

                        HStack(spacing: 24) {
                            aboutInfoRow(label: "Platform", value: "iPad")
                            aboutInfoRow(label: "Environment", value: "Production")
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("What's New")

                        Text("v1.0.0 — February 2026")
                            .font(.epilogue(14, weight: .bold))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.black)
                            .padding(.bottom, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            releaseNote("Document upload & management")
                            releaseNote("Course organization")
                            releaseNote("AI-powered quizzes")
                            releaseNote("Study analytics dashboard")
                        }
                    }
                }
            }

            // Row 2: Support | Social
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Support")

                        SettingsLinkRow(icon: "envelope", label: "Contact Support")
                        SettingsLinkRow(icon: "questionmark.circle", label: "Help Center")
                        SettingsLinkRow(icon: "ladybug", label: "Report a Bug")
                        SettingsLinkRow(icon: "bubble.left", label: "Send Feedback")
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Social")

                        SettingsLinkRow(icon: "at", label: "X / Twitter")
                        SettingsLinkRow(icon: "camera", label: "Instagram")
                        SettingsLinkRow(icon: "bubble.left.and.bubble.right", label: "Discord Community")
                        SettingsLinkRow(icon: "play.rectangle", label: "YouTube")
                    }
                }
            }

            // Row 3: Legal (full width)
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader("Legal")

                    HStack(spacing: 0) {
                        SettingsLinkRow(icon: "doc.text", label: "Terms of Service")
                            .frame(maxWidth: .infinity)
                        SettingsLinkRow(icon: "hand.raised", label: "Privacy Policy")
                            .frame(maxWidth: .infinity)
                        SettingsLinkRow(icon: "chevron.left.forwardslash.chevron.right", label: "Open Source Licenses")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.epilogue(11, weight: .bold))
                .tracking(0.06 * 11)
                .textCase(.uppercase)
                .foregroundStyle(ReefColors.gray500)

            Text(value)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.black)
        }
    }

    private func releaseNote(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ReefColors.primary)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
        }
    }
}

// MARK: ─── Account Tab ──────────────────────────────────

extension SettingsView {
    private var accountTab: some View {
        let tier: Tier = .shore
        let limits = TierLimits.current()

        return VStack(spacing: 16) {
            // Row 1: Your Plan | Security
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Your Plan")

                        Text("Shore")
                            .font(.epilogue(13, weight: .bold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(ReefColors.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ReefColors.accent)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(ReefColors.black, lineWidth: 1.5))
                            .padding(.bottom, 16)

                        usageBar(label: "Documents", current: 0, max: limits.maxDocuments)
                            .padding(.bottom, 12)

                        usageBar(label: "Courses", current: 0, max: limits.maxCourses)
                            .padding(.bottom, 12)

                        SettingsDivider()

                        HStack {
                            Text("Max File Size")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(ReefColors.gray600)
                            Spacer()
                            Text("\(limits.maxFileSizeMB) MB")
                                .font(.epilogue(13, weight: .bold))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(ReefColors.black)
                        }

                        Button {
                            showToast("Upgrades coming soon!")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle")
                                Text("Upgrade Plan")
                            }
                        }
                        .reefCompactStyle(.primary)
                        .padding(.top, 16)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Security")

                        SettingsFieldLabel("Sign-in Method")
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 13))
                                .foregroundStyle(ReefColors.primary)
                            Text("Magic Link")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.black)
                        }
                        Text(authManager.session?.user.email ?? "—")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(ReefColors.gray500)
                            .padding(.top, 2)

                        SettingsDivider()

                        SettingsFieldLabel("Two-Factor Authentication")
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ReefColors.gray400)
                                .frame(width: 8, height: 8)
                            Text("Not enabled")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(ReefColors.gray500)
                            Spacer()
                            Button("Enable") {}
                                .reefCompactStyle(.secondary)
                        }

                        SettingsDivider()

                        SettingsFieldLabel("Active Sessions")
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: 0x4CAF50))
                                .frame(width: 8, height: 8)
                            Text("This device — Active now")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(ReefColors.black)
                        }
                    }
                }
            }

            // Row 2: Compare Plans (full width)
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader("Compare Plans")

                    HStack(spacing: 12) {
                        planColumn(name: "Shore", price: "Free", color: ReefColors.accent, docs: "5", fileSize: "20 MB", courses: "1", isCurrent: tier == .shore)
                        planColumn(name: "Reef", price: "$9.99/mo", color: ReefColors.primary, docs: "50", fileSize: "50 MB", courses: "5", isCurrent: tier == .reef)
                        planColumn(name: "Abyss", price: "$29.99/mo", color: Color(hex: 0x6C3FA0), docs: "Unlimited", fileSize: "100 MB", courses: "Unlimited", isCurrent: tier == .abyss)
                    }
                }
            }

            // Row 3: Actions (full width)
            SettingsCard {
                HStack(spacing: 12) {
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .reefCompactStyle(.secondary)

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(Color(hex: 0xC62828))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ReefColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: 0xE57373), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(NoHighlightButtonStyle())

                    Spacer()
                }
            }
        }
    }

    private func usageBar(label: String, current: Int, max limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray600)
                Spacer()
                Text("\(current) / \(limit)")
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.black)
            }

            GeometryReader { geo in
                let pct = limit > 0 ? CGFloat(current) / CGFloat(limit) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(ReefColors.gray100)
                    Capsule()
                        .fill(ReefColors.primary)
                        .frame(width: max(geo.size.width * pct, 0))
                        .animation(.easeOut(duration: 0.6), value: appeared)
                }
            }
            .frame(height: 8)
        }
    }

    private func planColumn(name: String, price: String, color: Color, docs: String, fileSize: String, courses: String, isCurrent: Bool) -> some View {
        VStack(spacing: 12) {
            if isCurrent {
                Text("Current")
                    .font(.epilogue(10, weight: .bold))
                    .tracking(0.06 * 10)
                    .textCase(.uppercase)
                    .foregroundStyle(ReefColors.primary)
            }

            Text(name)
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)
                .foregroundStyle(ReefColors.black)

            Text(price)
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)

            SettingsDivider()

            planFeature(label: "Documents", value: docs)
            planFeature(label: "File Size", value: fileSize)
            planFeature(label: "Courses", value: courses)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? ReefColors.primary : ReefColors.gray200, lineWidth: isCurrent ? 2 : 1.5)
        )
    }

    private func planFeature(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.black)
            Text(label)
                .font(.epilogue(11, weight: .medium))
                .tracking(-0.04 * 11)
                .foregroundStyle(ReefColors.gray500)
        }
    }
}

// MARK: ─── Shared Components ────────────────────────────

private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            content
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .dashboardCard()
    }
}

private struct SettingsSectionHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.epilogue(11, weight: .bold))
            .tracking(0.06 * 11)
            .textCase(.uppercase)
            .foregroundStyle(ReefColors.gray500)
            .padding(.bottom, 16)
    }
}

private struct SettingsFieldLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.epilogue(13, weight: .medium))
            .tracking(-0.04 * 13)
            .foregroundStyle(ReefColors.gray600)
            .padding(.bottom, 8)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(ReefColors.gray100)
            .frame(height: 1)
            .padding(.vertical, 16)
    }
}

private struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.black)

            Spacer()

            SettingsToggle(isOn: $isOn)
        }
    }
}

private struct SettingsToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReefColors.primary : ReefColors.gray200)
                .frame(width: 52, height: 30)

            Circle()
                .fill(ReefColors.white)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                .padding(3)
        }
        .animation(.spring(duration: 0.25, bounce: 0.15), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

private struct SettingsSegmentedControl: View {
    let options: [String]
    let labels: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(options, labels)), id: \.0) { option, label in
                Text(label)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(selection == option ? ReefColors.white : ReefColors.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == option ? ReefColors.primary : ReefColors.white)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.black)
                .offset(x: 3, y: 3)
        )
        .compositingGroup()
        .animation(.spring(duration: 0.2), value: selection)
    }
}

private struct SettingsStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if value - step >= range.lowerBound { value -= step }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ReefColors.black)
                    .frame(width: 36, height: 36)
                    .background(ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ReefColors.black, lineWidth: 1.5)
                    )
            }
            .buttonStyle(NoHighlightButtonStyle())

            Text("\(value)")
                .font(.epilogue(18, weight: .bold))
                .tracking(-0.04 * 18)
                .foregroundStyle(ReefColors.black)
                .frame(minWidth: 40)

            Button {
                if value + step <= range.upperBound { value += step }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ReefColors.black)
                    .frame(width: 36, height: 36)
                    .background(ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ReefColors.black, lineWidth: 1.5)
                    )
            }
            .buttonStyle(NoHighlightButtonStyle())
        }
    }
}

private struct SettingsPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(isSelected ? ReefColors.white : ReefColors.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? ReefColors.primary : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ReefColors.black, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReefColors.black)
                    .offset(
                        x: isPressed ? 0 : 3,
                        y: isPressed ? 0 : 3
                    )
            )
            .offset(
                x: isPressed ? 3 : 0,
                y: isPressed ? 3 : 0
            )
            .animation(.spring(duration: 0.2, bounce: 0.1), value: isPressed)
            .animation(.spring(duration: 0.2, bounce: 0.1), value: isSelected)
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .accessibilityAddTraits(.isButton)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let label: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ReefColors.gray500)
                .frame(width: 20)

            Text(label)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.black)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ReefColors.gray400)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isHovered ? ReefColors.gray100 : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
