import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @State private var activeTab: SettingsTab = .profile
    @State private var appeared = false
    @State private var toastMessage: String?

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            headerSection(colors)
            tabBar
            tabContent
        }
        .padding(4)
        .padding(.trailing, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.contentPadding)
        .dashboardCard()
        .onAppear { appeared = true }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                toastView(message: message)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toastMessage)
    }

    // MARK: - Header

    private func headerSection(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.epilogue(24, weight: .black))
                .tracking(-0.04 * 24)
                .foregroundStyle(colors.text)

            Text("Manage your profile, preferences, and account.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
        }
        .padding(.horizontal, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.1), value: appeared)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(tab: tab, isActive: activeTab == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(0.18), value: appeared)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch activeTab {
            case .profile:
                SettingsProfileTab(onToast: showToast)
            case .preferences:
                SettingsPreferencesTab()
            case .privacy:
                SettingsPrivacyTab()
            case .about:
                SettingsAboutTab()
            case .account:
                SettingsAccountTab(onToast: showToast)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding([.trailing, .bottom], 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(0.24), value: appeared)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            toastMessage = nil
        }
    }

    private func toastView(message: String) -> some View {
        let colors = theme.colors
        return Text(message)
            .font(.epilogue(13, weight: .semiBold))
            .tracking(-0.04 * 13)
            .foregroundStyle(ReefColors.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(colors.text)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(colors.border, lineWidth: 1.5))
    }
}
