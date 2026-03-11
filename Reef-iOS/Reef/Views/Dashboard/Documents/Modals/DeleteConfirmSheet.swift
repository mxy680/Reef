import SwiftUI

struct DeleteConfirmSheet: View {
    let document: Document
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var isDeleting = false

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 0) {
            Text("Delete \"\(document.displayName)\"?")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .multilineTextAlignment(.center)

            Text("This action cannot be undone.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.top, 8)

            HStack(spacing: 10) {
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
