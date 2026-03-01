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
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Edit Course")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(ReefColors.black)
                .padding(.bottom, 24)

            // Name label + input
            Text("Course name")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.bottom, 6)

            TextField("e.g. Calculus II", text: $name)
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ReefColors.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ReefColors.gray400, lineWidth: 1.5)
                )
                .focused($isNameFocused)
                .onSubmit { submitIfValid() }
                .padding(.bottom, 20)

            // Emoji label + grid
            Text("Icon")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.bottom, 8)

            emojiGrid
                .padding(.bottom, 20)

            // Color label + picker
            Text("Accent color")
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.bottom, 8)

            colorPicker
                .padding(.bottom, 28)

            // Buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    onClose()
                }
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
                .buttonStyle(.plain)

                Button {
                    submitIfValid()
                } label: {
                    Text("Save")
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(canSave ? ReefColors.white : ReefColors.gray500)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(canSave ? ReefColors.primary : ReefColors.gray100)
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
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
        .background(ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ReefColors.black, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ReefColors.black)
                .offset(x: 6, y: 6)
        )
        .frame(maxWidth: 420)
        .onAppear { isNameFocused = true }
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 6), count: 8)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(emojiOptions, id: \.self) { em in
                let selected = emoji == em
                Button {
                    emoji = em
                } label: {
                    Text(em)
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(selected ? ReefColors.primary : ReefColors.white)
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
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(colorPresets, id: \.self) { c in
                let selected = selectedColor == c
                Button {
                    selectedColor = c
                } label: {
                    Circle()
                        .fill(Color(hex: c))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(selected ? ReefColors.black : ReefColors.gray400, lineWidth: selected ? 3 : 2)
                        )
                        .shadow(color: selected ? ReefColors.black.opacity(0.3) : .clear, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func submitIfValid() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onConfirm(trimmedName, emoji, selectedColor)
    }
}
