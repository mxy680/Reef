import SwiftUI
import Supabase

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthManager.self) var authManager
    @Environment(ThemeManager.self) var theme
    @State var activeTab: SettingsTab = .profile
    @State var appeared = false

    // Profile editing state
    @State var isEditingName = false
    @State var editedName = ""
    @State var selectedGrade = ""
    @State var selectedSubjects: [String] = []
    @State var educationDirty = false

    // Preferences state (local only, matching web)
    @State var selectedTheme = "#5B9EAD"
    @State var emailNotifications = true
    @State var studyReminders = false
    @State var weeklyDigest = true
    @State var focusWeakAreas = true
    @State var quizDifficulty = "medium"
    @State var questionCount = 10
    @State var quizTimer = "off"

    // Privacy state (local only)
    @State var usageAnalytics = true
    @State var crashReports = true
    @State var personalizedExperience = false
    @State var thirdPartySharing = false

    // Toast
    @State var toastMessage: String?

    // Delete confirmation
    @State var showDeleteConfirm = false

    let profileManager = ProfileManager()
    @Environment(\.layoutMetrics) var metrics

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                headerSection
                tabBar
                tabContent
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.contentPadding)
        .dashboardCard()
        .overlay(alignment: .bottomTrailing) { toastOverlay }
        .onAppear {
            appeared = true
            loadProfile()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        let dark = theme.isDarkMode
        return Text("Settings")
            .font(.epilogue(24, weight: .black))
            .tracking(-0.04 * 24)
            .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
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

    // MARK: - Helpers

    private func loadProfile() {
        guard let profile = authManager.profile else { return }
        editedName = profile.displayName ?? ""
        selectedGrade = profile.grade ?? ""
        selectedSubjects = profile.subjects
    }

    func showToast(_ message: String) {
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
