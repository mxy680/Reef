import SwiftUI

struct DeleteCourseSheet: View {
    let course: Course
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var isDeleting = false

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 0) {
            Text("Delete \"\(course.name)\"?")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .multilineTextAlignment(.center)

            Text("Documents in this course will be unlinked, not deleted.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .multilineTextAlignment(.center)
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

                Text(isDeleting ? "Deleting..." : "Delete")
                    .font(.epilogue(14, weight: .bold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xC62828))
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
                        isDeleting = true
                        onConfirm()
                    }
                    .accessibilityAddTraits(.isButton)
                    .allowsHitTesting(!isDeleting)
                    .opacity(isDeleting ? 0.4 : 1)
            }
            .padding(.top, 24)
        }
        .padding(32)
        .popupShell()
    }
}
