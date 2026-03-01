import SwiftUI

struct RenameSheet: View {
    let document: Document
    let onConfirm: (String) -> Void
    let onClose: () -> Void

    @State private var name: String
    @FocusState private var isFocused: Bool

    init(document: Document, onConfirm: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.document = document
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: document.displayName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rename Document")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)

            TextField("Document name", text: $name)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .padding(12)
                .background(ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ReefColors.gray400, lineWidth: 1.5)
                )
                .focused($isFocused)
                .onSubmit { submitIfValid() }
                .padding(.top, 16)

            HStack {
                Spacer()

                Button("Cancel") {
                    onClose()
                }
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)

                Button {
                    submitIfValid()
                } label: {
                    Text("Rename")
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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.top, 20)
        }
        .padding(28)
        .presentationDetents([.height(220)])
        .onAppear { isFocused = true }
    }

    private func submitIfValid() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed + ".pdf")
    }
}
