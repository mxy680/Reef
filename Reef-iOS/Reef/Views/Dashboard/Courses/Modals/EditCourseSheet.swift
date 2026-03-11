import SwiftUI

private let iconOptions = [
    "course.dolphin", "course.sea_turtle", "course.octopus", "course.whale",
    "course.seahorse", "course.jellyfish", "course.starfish", "course.shark",
    "course.crab", "course.clownfish", "course.pufferfish", "course.manta_ray",
    "course.lobster", "course.seal", "course.narwhal", "course.squid",
    "course.orca", "course.manatee", "course.coral", "course.shrimp",
    "course.swordfish", "course.hermit_crab", "course.angelfish", "course.sea_otter",
]

private let colorPresets = [
    "#5B9EAD", "#E07A5F", "#81B29A", "#F2CC8F",
    "#3D405B", "#A78BFA", "#F87171", "#34D399",
]

struct EditCourseSheet: View {
    let course: Course
    let onConfirm: (String, String, String) -> Void // (name, icon, color)
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @FocusState private var isNameFocused: Bool

    init(course: Course, onConfirm: @escaping (String, String, String) -> Void, onClose: @escaping () -> Void) {
        self.course = course
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: course.name)
        // Fall back to first icon if the stored emoji is a legacy emoji character
        let icon = course.emoji
        self._selectedIcon = State(initialValue: iconOptions.contains(icon) ? icon : iconOptions[0])
        self._selectedColor = State(initialValue: course.color.isEmpty ? colorPresets[0] : course.color)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        let dark = theme.isDarkMode
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Edit Course")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .padding(.bottom, 24)

            // Name label + input
            Text("Course name")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.bottom, 6)

            TextField("e.g. Calculus II", text: $name)
                .textFieldStyle(.plain)
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
                )
                .focused($isNameFocused)
                .onSubmit { submitIfValid() }
                .padding(.bottom, 20)

            // Icon label + grid
            Text("Icon")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.bottom, 8)

            iconGrid
                .padding(.bottom, 20)

            // Color label + picker
            Text("Accent color")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.bottom, 8)

            colorPicker
                .padding(.bottom, 28)

            // Buttons
            HStack {
                Spacer()

                Text("Cancel")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
                    .accessibilityAddTraits(.isButton)

                ReefModalButton("Save", isEnabled: canSave) {
                    submitIfValid()
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
        .popupShell(cornerRadius: 12, maxWidth: 420, shadowOffset: 6)
        .onAppear { isNameFocused = true }
    }

    // MARK: - Icon Grid

    private var iconGrid: some View {
        let dark = theme.isDarkMode
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 6), count: 8)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(iconOptions, id: \.self) { icon in
                let selected = selectedIcon == icon
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(selected ? ReefColors.white : ReefColors.gray600)
                    .frame(width: 40, height: 40)
                    .background(selected ? ReefColors.primary : (dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .reef3DPush(
                        cornerRadius: 10,
                        shadowOffset: 3,
                        borderColor: ReefColors.black,
                        shadowColor: ReefColors.black
                    ) {
                        selectedIcon = icon
                    }
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(colorPresets, id: \.self) { c in
                Circle()
                    .fill(Color(hex: c))
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .reef3DPushCircle(
                        borderWidth: selectedColor == c ? 3 : 2,
                        borderColor: selectedColor == c ? ReefColors.black : ReefColors.gray400,
                        shadowColor: ReefColors.black
                    ) {
                        selectedColor = c
                    }
            }
        }
    }

    private func submitIfValid() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onConfirm(trimmedName, selectedIcon, selectedColor)
    }
}
