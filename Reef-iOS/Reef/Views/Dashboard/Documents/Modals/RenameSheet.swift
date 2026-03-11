import SwiftUI

struct RenameSheet: View {
    let document: Document
    let onConfirm: (String) -> Void
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(document: Document, onConfirm: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.document = document
        self.onConfirm = onConfirm
        self.onClose = onClose
        self._name = State(initialValue: document.displayName)
    }

    var body: some View {
        let dark = theme.isDarkMode
        VStack(alignment: .leading, spacing: 0) {
            Text("Rename Document")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            TextField("Document name", text: $name)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .padding(12)
                .background(dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
                )
                .focused($isFocused)
                .onSubmit { submitIfValid() }
                .padding(.top, 16)

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

                ReefModalButton("Rename", isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                    submitIfValid()
                }
            }
            .padding(.top, 20)
        }
        .padding(32)
        .popupShell()
        .onAppear { isFocused = true }
    }

    private func submitIfValid() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed + ".pdf")
    }
}
