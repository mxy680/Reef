//
//  SettingsView.swift
//  Reef
//
//  Settings home — grid of cards that navigate into detail views.
//

import SwiftUI

// MARK: - Section Enum

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case account, ai, study, privacy, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return "Account"
        case .ai:      return "AI"
        case .study:   return "Study"
        case .privacy: return "Privacy"
        case .about:   return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .account: return "Profile & sign-in"
        case .ai:      return "Models & feedback"
        case .study:   return "Quiz & exam defaults"
        case .privacy: return "Data & analytics"
        case .about:   return "Info & support"
        }
    }

    var icon: String {
        switch self {
        case .account: return "person.crop.circle"
        case .ai:      return "brain"
        case .study:   return "book"
        case .privacy: return "lock.shield"
        case .about:   return "info.circle"
        }
    }
}

// MARK: - Card Component

struct SettingsCategoryCard: View {
    let section: SettingsSection
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color.deepTeal)

            Text(section.title)
                .font(.quicksand(17, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            Text(section.subtitle)
                .font(.quicksand(13, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.warmDarkCard : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(value: section) {
                        SettingsCategoryCard(
                            section: section,
                            colorScheme: effectiveColorScheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationDestination(for: SettingsSection.self) { section in
            switch section {
            case .account: AccountSettingsView(authManager: authManager)
            case .ai:      AISettingsView()
            case .study:   StudySettingsView()
            case .privacy: PrivacySettingsView()
            case .about:   AboutView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(authManager: AuthenticationManager())
    }
}
