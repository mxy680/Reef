import SwiftUI

struct DeleteCoursePopup: View {
    let course: Course
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(ReefTheme.self) private var theme
    @State private var isDeleting = false

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            Text("Delete \"\(course.name)\"?")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)

            Text("Documents in this course will be unlinked, not deleted.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
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
