import SwiftUI

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case profile, preferences, privacy, about, account

    var id: String { rawValue }

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
        case .profile: "person.circle"
        case .preferences: "slider.horizontal.3"
        case .privacy: "lock.shield"
        case .about: "info.circle"
        case .account: "creditcard"
        }
    }
}

// MARK: - Constants

let settingsGrades = ["9th", "10th", "11th", "12th", "Freshman", "Sophomore", "Junior", "Senior", "Graduate"]

let settingsAllSubjects = [
    "Mathematics", "Calculus", "Statistics", "Biology", "Chemistry", "Physics",
    "History", "Literature", "Computer Science", "Economics", "Psychology", "Philosophy"
]

let settingsAvatarColors: [Color] = [
    Color(hex: 0xFCEBD5), Color(hex: 0xD5EBF0), Color(hex: 0xD5F0E0),
    Color(hex: 0xF0D5E8), Color(hex: 0xE8E8D5), Color(hex: 0xD5D5F0),
]

let settingsThemeColors: [Color] = [
    ReefColors.primary,
    Color(hex: 0xE07A5F),
    Color(hex: 0x81B29A),
    Color(hex: 0xF2CC8F),
    ReefColors.abyss,
    Color(hex: 0xD4A5A5),
]

// MARK: - SettingsRow

struct SettingsRow<Content: View>: View {
    @Environment(\.reefLayoutMetrics) private var metrics
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: metrics.sectionSpacing) {
            content()
        }
    }
}

// MARK: - SettingsCard

struct SettingsCard<Content: View>: View {
    @Environment(\.reefLayoutMetrics) private var metrics
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }
}

// MARK: - SettingsSectionHeader

struct SettingsSectionHeader: View {
    @Environment(ReefTheme.self) private var theme
    let title: String

    var body: some View {
        let colors = theme.colors
        Text(title.uppercased())
            .font(.epilogue(11, weight: .bold))
            .tracking(0.06 * 11)
            .foregroundStyle(colors.textMuted)
    }
}

// MARK: - SettingsFieldLabel

struct SettingsFieldLabel: View {
    @Environment(ReefTheme.self) private var theme
    let title: String

    var body: some View {
        let colors = theme.colors
        Text(title)
            .font(.epilogue(13, weight: .medium))
            .tracking(-0.04 * 13)
            .foregroundStyle(colors.textSecondary)
    }
}

// MARK: - SettingsDivider

struct SettingsDivider: View {
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        Rectangle()
            .fill(colors.divider)
            .frame(height: 1)
            .padding(.vertical, 12)
    }
}

// MARK: - SettingsToggle

struct SettingsToggle: View {
    @Environment(ReefTheme.self) private var theme
    @Binding var isOn: Bool

    private let width: CGFloat = 52
    private let height: CGFloat = 30
    private let thumbSize: CGFloat = 22

    var body: some View {
        let colors = theme.colors
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReefColors.primary : colors.subtle)
                .overlay(Capsule().stroke(colors.border, lineWidth: 1.5))
                .frame(width: width, height: height)

            Circle()
                .fill(ReefColors.white)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(Circle().stroke(colors.border, lineWidth: 1))
                .padding(4)
                .shadow(color: colors.shadow.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .animation(.spring(duration: 0.2, bounce: 0.3), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SettingsToggleRow

struct SettingsToggleRow: View {
    @Environment(ReefTheme.self) private var theme
    let label: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(label: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        let colors = theme.colors
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                }
            }

            Spacer()

            SettingsToggle(isOn: $isOn)
        }
    }
}

// MARK: - SettingsSegmentedControl

struct SettingsSegmentedControl: View {
    @Environment(ReefTheme.self) private var theme
    let options: [String]
    @Binding var selection: String

    var body: some View {
        let colors = theme.colors
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option
                Text(option)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(isSelected ? colors.text : colors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? colors.card : colors.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? colors.border : Color.clear, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.easeInOut(duration: 0.15), value: selection)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option }
            }
        }
        .padding(4)
        .background(colors.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.border, lineWidth: 1.5))
    }
}

// MARK: - SettingsStepper

struct SettingsStepper: View {
    @Environment(ReefTheme.self) private var theme
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    init(value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1) {
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        let colors = theme.colors
        HStack(spacing: 0) {
            stepButton(icon: "minus") {
                if value - step >= range.lowerBound { value -= step }
            }

            Text("\(value)")
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)
                .frame(minWidth: 40)
                .multilineTextAlignment(.center)

            stepButton(icon: "plus") {
                if value + step <= range.upperBound { value += step }
            }
        }
        .background(colors.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1.5))
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        let colors = theme.colors
        return Image(systemName: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(colors.textSecondary)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }
}

// MARK: - SettingsPill

struct SettingsPill: View {
    @Environment(ReefTheme.self) private var theme
    let label: String
    let isSelected: Bool
    var horizontalPadding: CGFloat = 14
    let action: () -> Void

    @State private var isPressed = false
    private let springBackDelay: TimeInterval = 0.18

    var body: some View {
        let colors = theme.colors
        Text(label)
            .font(.epilogue(12, weight: .bold))
            .tracking(-0.04 * 12)
            .foregroundStyle(isSelected ? ReefColors.white : colors.text)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
            .background(isSelected ? ReefColors.primary : colors.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(colors.border, lineWidth: 1.5))
            .background(
                Capsule()
                    .fill(colors.shadow)
                    .offset(x: isPressed ? 0 : 3, y: isPressed ? 0 : 3)
            )
            .offset(x: isPressed ? 3 : 0, y: isPressed ? 3 : 0)
            .compositingGroup()
            .animation(.spring(duration: 0.15, bounce: 0.15), value: isPressed)
            .contentShape(Capsule())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(springBackDelay))
                            action()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SettingsLinkRow

struct SettingsLinkRow: View {
    @Environment(ReefTheme.self) private var theme
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        let colors = theme.colors
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(colors.textSecondary)
                .frame(width: 22)

            Text(label)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.textDisabled)
        }
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SettingsTabButton

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        ReefButton(isActive ? .primary : .secondary, size: .compact, action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.label)
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

