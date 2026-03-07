@preconcurrency import Supabase
import SwiftUI

struct SelectCoursePopup: View {
    let filename: String
    let onConfirm: (String?) -> Void
    let onDismiss: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var courses: [Course] = []
    @State private var isLoading = true

    var body: some View {
        let dark = theme.isDarkMode
        VStack(spacing: 0) {
            // Close button row
            HStack {
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                    .frame(width: 28, height: 28)
                    .background(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100)
                    .clipShape(Circle())
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                Text("Select Course")
                    .font(.epilogue(20, weight: .black))
                    .tracking(-0.04 * 20)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                Text(filename.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive))
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                    .padding(.top, 6)

                if isLoading {
                    Text("Loading courses...")
                        .font(.epilogue(13, weight: .medium))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 6) {
                        // Skip course selection
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)

                            Text("Skip — no course")
                                .font(.epilogue(13, weight: .semiBold))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
                        )
                        .compositingGroup()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onConfirm(nil)
                        }
                        .accessibilityAddTraits(.isButton)

                        ForEach(courses) { course in
                            HStack(spacing: 10) {
                                Image(course.emoji)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(ReefColors.gray600)

                                Text(course.name)
                                    .font(.epilogue(13, weight: .semiBold))
                                    .tracking(-0.04 * 13)
                                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
                            )
                            .compositingGroup()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onConfirm(course.id)
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .padding(24)
        .popupShell(maxWidth: 420)
        .task {
            do {
                courses = try await supabase
                    .from("courses")
                    .select()
                    .order("created_at")
                    .execute()
                    .value
            } catch {
                // Silently fail — shows "no courses" state
            }
            isLoading = false
        }
    }
}
