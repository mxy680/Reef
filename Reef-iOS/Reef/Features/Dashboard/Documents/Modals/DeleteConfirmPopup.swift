import SwiftUI

struct DeleteConfirmPopup: View {
    let document: Document
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(ReefTheme.self) private var theme
    @State private var isDeleting = false

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            Text("Delete \"\(document.displayName)\"?")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)

            Text("This action cannot be undone.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 8)

            HStack(spacing: 10) {
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

                ReefModalButton(isDeleting ? "Deleting..." : "Delete", variant: .destructive, isEnabled: !isDeleting) {
                    isDeleting = true
                    onConfirm()
                }
            }
            .padding(.top, 24)
        }
        .padding(32)
        .popupShell()
    }
}
