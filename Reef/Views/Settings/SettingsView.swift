//
//  SettingsView.swift
//  Reef
//
//  Settings home — bento box grid that navigates into detail views.
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
        case .account: return "person.crop.circle.fill"
        case .ai:      return "brain.fill"
        case .study:   return "book.fill"
        case .privacy: return "lock.shield.fill"
        case .about:   return "info.circle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .account: return Color.deepTeal
        case .ai:      return Color(hex: "8B5CF6")
        case .study:   return Color.deepCoral
        case .privacy: return Color(hex: "3B82F6")
        case .about:   return Color(hex: "F59E0B")
        }
    }

    var gradient: [Color] {
        switch self {
        case .account: return [Color.deepTeal, Color.seafoam]
        case .ai:      return [Color(hex: "8B5CF6"), Color(hex: "C4B5FD")]
        case .study:   return [Color.deepCoral, Color.softCoral]
        case .privacy: return [Color(hex: "3B82F6"), Color(hex: "93C5FD")]
        case .about:   return [Color(hex: "F59E0B"), Color(hex: "FDE68A")]
        }
    }
}

// MARK: - Bento Card

private struct BentoCard: View {
    let section: SettingsSection
    let colorScheme: ColorScheme
    var isHero: Bool = false

    var body: some View {
        if isHero {
            heroContent
        } else {
            standardContent
        }
    }

    // Hero card — gradient fill, white text
    private var heroContent: some View {
        VStack(spacing: 16) {
            Image(systemName: section.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))

            Text(section.title)
                .font(.quicksand(22, weight: .bold))
                .foregroundColor(.white)

            Text(section.subtitle)
                .font(.quicksand(14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: section.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            // Subtle inner highlight
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: section.accent.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    // Standard card — tinted background, icon badge, adaptive text
    private var standardContent: some View {
        VStack(spacing: 10) {
            // Icon on a colored circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: section.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                )

            Text(section.title)
                .font(.quicksand(16, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            Text(section.subtitle)
                .font(.quicksand(11, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark
                      ? Color.warmDarkCard
                      : Color.white)
        )
        .overlay(
            // Subtle tinted top edge
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [section.accent.opacity(0.4), section.accent.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: section.accent.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    // Layout constants
    private let gap: CGFloat = 14
    private let topRowHeight: CGFloat = 240
    private let bottomRowHeight: CGFloat = 160

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let w = geo.size.width
                let leftCol = (w - gap) * 0.58
                let rightCol = (w - gap) * 0.42
                let smallCardH = (topRowHeight - gap) / 2
                let botLeft = (w - gap) * 0.42
                let botRight = (w - gap) * 0.58

                VStack(spacing: gap) {
                    // ┌──────────────┬──────────┐
                    // │              │    AI    │
                    // │   Account    ├──────────┤
                    // │              │  Study   │
                    // └──────────────┴──────────┘
                    HStack(spacing: gap) {
                        bentoLink(.account, isHero: true)
                            .frame(width: leftCol, height: topRowHeight)

                        VStack(spacing: gap) {
                            bentoLink(.ai)
                                .frame(height: smallCardH)
                            bentoLink(.study)
                                .frame(height: smallCardH)
                        }
                        .frame(width: rightCol, height: topRowHeight)
                    }

                    // ┌─────────┬───────────────┐
                    // │ Privacy │     About      │
                    // └─────────┴───────────────┘
                    HStack(spacing: gap) {
                        bentoLink(.privacy)
                            .frame(width: botLeft, height: bottomRowHeight)
                        bentoLink(.about)
                            .frame(width: botRight, height: bottomRowHeight)
                    }
                }
            }
            .frame(height: topRowHeight + gap + bottomRowHeight)
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

    private func bentoLink(_ section: SettingsSection, isHero: Bool = false) -> some View {
        NavigationLink(value: section) {
            BentoCard(
                section: section,
                colorScheme: effectiveColorScheme,
                isHero: isHero
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView(authManager: AuthenticationManager())
    }
}
