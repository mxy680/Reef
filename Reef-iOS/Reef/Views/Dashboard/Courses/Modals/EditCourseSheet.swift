import SwiftUI

private let emojiOptions = [
    "📐", "🧪", "💻", "📊", "🔬", "📝", "🧮", "🎨",
    "🌍", "📖", "🧬", "⚡", "🏛️", "🎵", "💰", "🔧",
    "📈", "🧠", "🌿", "🔢", "💡", "🏗️", "📚", "✏️",
]

private let colorPresets = [
    "#5B9EAD", "#E07A5F", "#81B29A", "#F2CC8F",
    "#3D405B", "#A78BFA", "#F87171", "#34D399",
]

struct EditCourseSheet: View {
    let course: Course
    let onConfirm: (String, String, String) -> Void // (name, emoji, color)
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var name: String
    @State private var emoji: String
    @State private var selectedColor: String
    @FocusState private var isNameFocused: Bool

    init(course: Course, onConfirm: @escaping (String, String, String) -> Void, onClose: @escaping () -> Void) {
        self.course = course
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: course.name)
        self._emoji = State(initialValue: course.emoji)
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

            // Emoji label + grid
            Text("Icon")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.bottom, 8)

            emojiGrid
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

                Text("Save")
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(canSave ? ReefColors.white : (dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(canSave ? ReefColors.primary : (dark ? ReefColors.DashboardDark.divider : ReefColors.gray100))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReefColors.black, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ReefColors.black)
                            .offset(x: 4, y: 4)
                    )
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        submitIfValid()
                    }
                    .accessibilityAddTraits(.isButton)
                    .allowsHitTesting(canSave)
                    .opacity(!canSave ? 0.4 : 1)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
        .popupShell(cornerRadius: 12, maxWidth: 420, shadowOffset: 6)
        .onAppear { isNameFocused = true }
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        let dark = theme.isDarkMode
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 6), count: 8)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(emojiOptions, id: \.self) { em in
                let selected = emoji == em
                Text(em)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(selected ? ReefColors.primary : (dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReefColors.black, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ReefColors.black)
                            .offset(x: 3, y: 3)
                    )
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        emoji = em
                    }
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(colorPresets, id: \.self) { c in
                let selected = selectedColor == c
                Circle()
                    .fill(Color(hex: c))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(selected ? ReefColors.black : ReefColors.gray400, lineWidth: selected ? 3 : 2)
                    )
                    .shadow(color: selected ? ReefColors.black.opacity(0.3) : .clear, radius: 0, x: 2, y: 2)
                    .contentShape(Circle())
                    .onTapGesture {
                        selectedColor = c
                    }
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func submitIfValid() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onConfirm(trimmedName, emoji, selectedColor)
    }
}
