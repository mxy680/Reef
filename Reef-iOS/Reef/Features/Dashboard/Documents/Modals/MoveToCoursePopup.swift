@preconcurrency import Supabase
import SwiftUI

struct MoveToCoursePopup: View {
    let document: Document
    let onConfirm: (String?) -> Void
    let onClose: () -> Void

    @Environment(ReefTheme.self) private var theme
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var selectedCourseId: String?

    private var hasChange: Bool {
        selectedCourseId != document.courseId
    }

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Move to Course")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)

            Text(document.displayName)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 6)

            if isLoading {
                Text("Loading courses...")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textMuted)
                    .padding(.top, 16)
            } else if courses.isEmpty {
                Text("No courses yet. Create one first.")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textMuted)
                    .padding(.top, 16)
            } else {
                // Dropdown picker
                Menu {
                    // "No course" option
                    Button {
                        selectedCourseId = nil
                    } label: {
                        Label("No course", systemImage: selectedCourseId == nil ? "checkmark" : "")
                    }

                    Divider()

                    ForEach(courses) { course in
                        Button {
                            selectedCourseId = course.id
                        } label: {
                            Label {
                                HStack(spacing: 6) {
                                    Image(course.emoji)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                    Text(course.name)
                                }
                            } icon: {
                                if selectedCourseId == course.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let id = selectedCourseId,
                           let course = courses.first(where: { $0.id == id }) {
                            HStack(spacing: 6) {
                                Image(course.emoji)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(colors.textSecondary)
                                Text(course.name)
                                    .font(.epilogue(14, weight: .semiBold))
                                    .tracking(-0.04 * 14)
                                    .foregroundStyle(colors.text)
                            }
                        } else {
                            Text("No course")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(colors.textMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(colors.textMuted)
                    }
                    .padding(12)
                    .background(colors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colors.textDisabled, lineWidth: 1.5)
                    )
                }
                .padding(.top, 20)
            }

            HStack {
                Spacer()

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

                ReefModalButton(
                    selectedCourseId == nil && document.courseId != nil ? "Remove" : "Move",
                    isEnabled: hasChange
                ) {
                    onConfirm(selectedCourseId)
                }
            }
            .padding(.top, 20)
        }
        .padding(32)
        .popupShell()
        .task {
            selectedCourseId = document.courseId
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
