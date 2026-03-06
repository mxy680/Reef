@preconcurrency import Supabase
import SwiftUI

struct MoveToCourseSheet: View {
    let document: Document
    let onConfirm: (String?) -> Void
    let onClose: () -> Void

    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var selectedCourseId: String?

    private var hasChange: Bool {
        selectedCourseId != document.courseId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Move to Course")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)

            Text(document.displayName)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.top, 6)

            if isLoading {
                Text("Loading courses...")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray500)
                    .padding(.top, 16)
            } else if courses.isEmpty {
                Text("No courses yet. Create one first.")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray500)
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
                            Label(
                                "\(course.emoji) \(course.name)",
                                systemImage: selectedCourseId == course.id ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    HStack {
                        if let id = selectedCourseId,
                           let course = courses.first(where: { $0.id == id }) {
                            Text("\(course.emoji) \(course.name)")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.black)
                        } else {
                            Text("No course")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.gray500)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ReefColors.gray500)
                    }
                    .padding(12)
                    .background(ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReefColors.gray400, lineWidth: 1.5)
                    )
                }
                .padding(.top, 20)
            }

            HStack {
                Spacer()

                Text("Cancel")
                    .font(.epilogue(14, weight: .semiBold))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.gray600)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
                    .accessibilityAddTraits(.isButton)

                Text(selectedCourseId == nil && document.courseId != nil ? "Remove" : "Move")
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
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if hasChange {
                            onConfirm(selectedCourseId)
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .allowsHitTesting(hasChange)
                    .opacity(hasChange ? 1 : 0.4)
            }
            .padding(.top, 20)
        }
        .padding(32)
        .background(ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReefColors.black, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ReefColors.black)
                .offset(x: 4, y: 4)
        )
        .frame(maxWidth: 400)
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
