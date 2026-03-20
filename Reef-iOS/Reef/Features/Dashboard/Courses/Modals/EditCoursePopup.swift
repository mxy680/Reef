import SwiftUI

struct EditCoursePopup: View {
    let course: Course
    let onConfirm: (String, String, String) -> Void // (name, icon, color)
    let onClose: () -> Void

    @Environment(ReefTheme.self) private var theme
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @FocusState private var isNameFocused: Bool

    init(course: Course, onConfirm: @escaping (String, String, String) -> Void, onClose: @escaping () -> Void) {
        self.course = course
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: course.name)
        // Fall back to first icon if the stored value is not a known asset name
        let icon = course.emoji
        self._selectedIcon = State(initialValue: courseIconOptions.contains(icon) ? icon : courseIconOptions[0])
        self._selectedColor = State(initialValue: course.color.isEmpty ? courseColorPresets[0] : course.color)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Course")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(colors.text)
                .padding(.bottom, 24)

            Text("Course name")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 6)

            TextField("e.g. Calculus II", text: $name)
                .textFieldStyle(.plain)
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(colors.cardElevated)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colors.border, lineWidth: 1.5)
                )
                .focused($isNameFocused)
                .onSubmit { submitIfValid() }
                .padding(.bottom, 20)

            Text("Icon")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 8)

            iconGrid(colors: colors)
                .padding(.bottom, 20)

            Text("Accent color")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 8)

            colorPicker
                .padding(.bottom, 28)

            HStack {
                Spacer()

                Text("Cancel")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(colors.textSecondary)
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

    private func iconGrid(colors: ReefThemeColors) -> some View {
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 6), count: 8)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(courseIconOptions, id: \.self) { icon in
                let selected = selectedIcon == icon
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(selected ? ReefColors.white : ReefColors.gray600)
                    .frame(width: 40, height: 40)
                    .background(selected ? ReefColors.primary : colors.cardElevated)
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
            ForEach(courseColorPresets, id: \.self) { c in
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

    // MARK: - Submit

    private func submitIfValid() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onConfirm(trimmedName, selectedIcon, selectedColor)
    }
}
