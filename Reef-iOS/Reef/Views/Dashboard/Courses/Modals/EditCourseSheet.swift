import SwiftUI

struct EditCourseSheet: View {
    let course: Course
    let onConfirm: (String, String) -> Void // (name, emoji)
    let onClose: () -> Void

    @State private var name: String
    @State private var emoji: String
    @FocusState private var isNameFocused: Bool

    init(course: Course, onConfirm: @escaping (String, String) -> Void, onClose: @escaping () -> Void) {
        self.course = course
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: course.name)
        self._emoji = State(initialValue: course.emoji)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Course")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)

            HStack(spacing: 10) {
                TextField("📚", text: $emoji)
                    .font(.system(size: 24))
                    .multilineTextAlignment(.center)
                    .frame(width: 48, height: 44)
                    .background(ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ReefColors.gray400, lineWidth: 1.5)
                    )

                TextField("Course name", text: $name)
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .padding(12)
                    .background(ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ReefColors.gray400, lineWidth: 1.5)
                    )
                    .focused($isNameFocused)
                    .onSubmit { submitIfValid() }
            }
            .padding(.top, 16)

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
                        .foregroundStyle(ReefColors.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(ReefColors.primary)
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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.top, 20)
        }
        .padding(28)
        .presentationDetents([.height(240)])
        .onAppear { isNameFocused = true }
    }

    private func submitIfValid() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        onConfirm(trimmedName, trimmedEmoji.isEmpty ? "📚" : trimmedEmoji)
    }
}
