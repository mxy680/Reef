import SwiftUI

// MARK: - Settings Constants

let settingsGrades: [(value: String, label: String)] = [
    ("middle_school", "Middle School"),
    ("high_school", "High School"),
    ("college", "College"),
    ("graduate", "Graduate"),
    ("other", "Other"),
]

let settingsAllSubjects = [
    "Algebra", "Geometry", "Precalculus", "Calculus", "Statistics",
    "Linear Algebra", "Trigonometry", "Differential Equations",
    "Physics", "Chemistry", "Biology", "Computer Science",
    "Economics", "Engineering", "Accounting",
]

let settingsThemeColors: [(color: Color, hex: String)] = [
    (Color(hex: 0x5B9EAD), "#5B9EAD"),
    (Color(hex: 0xE07A5F), "#E07A5F"),
    (Color(hex: 0x81B29A), "#81B29A"),
    (Color(hex: 0xF2CC8F), "#F2CC8F"),
    (Color(hex: 0x3D405B), "#3D405B"),
    (Color(hex: 0xA78BFA), "#A78BFA"),
]

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
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

// MARK: - Layout Components

struct SettingsRow<Content: View>: View {
    @Environment(\.layoutMetrics) private var metrics
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: metrics.sectionSpacing) {
            content
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsCard<Content: View>: View {
    @Environment(\.layoutMetrics) private var metrics
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.cardPadding)
        .dashboardCard()
    }
}

// MARK: - Text Components

struct SettingsSectionHeader: View {
    @Environment(ThemeManager.self) private var theme
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        let dark = theme.isDarkMode
        Text(text)
            .font(.epilogue(11, weight: .bold))
            .tracking(0.06 * 11)
            .textCase(.uppercase)
            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
            .padding(.bottom, 16)
    }
}

struct SettingsFieldLabel: View {
    @Environment(ThemeManager.self) private var theme
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        let dark = theme.isDarkMode
        Text(text)
            .font(.epilogue(13, weight: .medium))
            .tracking(-0.04 * 13)
            .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
            .padding(.bottom, 8)
    }
}

struct SettingsDivider: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        Rectangle()
            .fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100)
            .frame(height: 1)
            .padding(.vertical, 16)
    }
}

// MARK: - Interactive Components

struct SettingsToggleRow: View {
    @Environment(ThemeManager.self) private var theme
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        let dark = theme.isDarkMode
        HStack {
            Text(label)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Spacer()

            SettingsToggle(isOn: $isOn)
        }
    }
}

struct SettingsToggle: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var isOn: Bool

    var body: some View {
        let dark = theme.isDarkMode
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReefColors.primary : (dark ? ReefColors.DashboardDark.divider : ReefColors.gray200))
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

struct SettingsSegmentedControl: View {
    @Environment(ThemeManager.self) private var theme
    let options: [String]
    let labels: [String]
    @Binding var selection: String

    var body: some View {
        let dark = theme.isDarkMode
        HStack(spacing: 0) {
            ForEach(Array(zip(options, labels)), id: \.0) { option, label in
                Text(label)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(selection == option ? ReefColors.white : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == option ? ReefColors.primary : (dark ? ReefColors.DashboardDark.card : ReefColors.white))
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
                .offset(x: 3, y: 3)
        )
        .compositingGroup()
        .animation(.spring(duration: 0.2), value: selection)
    }
}

struct SettingsStepper: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        let dark = theme.isDarkMode
        HStack(spacing: 12) {
            Button {
                if value - step >= range.lowerBound { value -= step }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                    .frame(width: 36, height: 36)
                    .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
                    )
            }
            .buttonStyle(NoHighlightButtonStyle())

            Text("\(value)")
                .font(.epilogue(18, weight: .bold))
                .tracking(-0.04 * 18)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .frame(minWidth: 40)

            Button {
                if value + step <= range.upperBound { value += step }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                    .frame(width: 36, height: 36)
                    .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
                    )
            }
            .buttonStyle(NoHighlightButtonStyle())
        }
    }
}

struct SettingsPill: View {
    @Environment(ThemeManager.self) private var theme
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        let dark = theme.isDarkMode
        Text(label)
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(isSelected ? ReefColors.white : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? ReefColors.primary : (dark ? ReefColors.DashboardDark.card : ReefColors.white))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
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

struct SettingsLinkRow: View {
    @Environment(ThemeManager.self) private var theme
    let icon: String
    let label: String
    @State private var isHovered = false

    var body: some View {
        let dark = theme.isDarkMode
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                .frame(width: 20)

            Text(label)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isHovered ? (dark ? ReefColors.DashboardDark.subtle : ReefColors.gray100) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

struct SettingsTabButton: View {
    @Environment(ThemeManager.self) private var theme
    let tab: SettingsTab
    let isActive: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        let dark = theme.isDarkMode
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
            Text(tab.label)
                .font(.epilogue(13, weight: .bold))
                .tracking(-0.04 * 13)
        }
        .foregroundStyle(isActive ? ReefColors.white : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? ReefColors.primary : (dark ? ReefColors.DashboardDark.card : ReefColors.white))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
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
