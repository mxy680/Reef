@preconcurrency import Supabase
import SwiftUI

struct DocumentUploadPopup: View {
    let filename: String
    let onConfirm: (String?, Bool) -> Void
    let onClose: () -> Void

    @Environment(ReefTheme.self) private var theme
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var selectedCourseId: String?
    @State private var reconstruct = true

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Upload Document")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)

            Text(filename)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 6)

            // Course picker
            Text("Course")
                .font(.epilogue(13, weight: .bold))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 24)

            if isLoading {
                Text("Loading courses...")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textMuted)
                    .padding(.top, 8)
            } else {
                Menu {
                    Button {
                        selectedCourseId = nil
                    } label: {
                        Label("No course", systemImage: selectedCourseId == nil ? "checkmark" : "")
                    }

                    if !courses.isEmpty {
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
                .padding(.top, 8)
            }

            // Reconstruct toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconstruct document")
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)

                    Text("Extracts questions and enables tutoring")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                Toggle("", isOn: $reconstruct)
                    .labelsHidden()
                    .tint(ReefColors.primary)
            }
            .padding(.top, 24)

            // Buttons
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

                ReefModalButton("Upload") {
                    onConfirm(selectedCourseId, reconstruct)
                }
            }
            .padding(.top, 20)
        }
        .padding(32)
        .popupShell()
        .task {
            do {
                let dtos: [CourseDTO] = try await supabase
                    .from("courses")
                    .select()
                    .order("created_at")
                    .execute()
                    .value
                courses = dtos.map { $0.toDomain() }
            } catch {
                // Silently fail — shows "No course" only
            }
            isLoading = false
        }
    }
}
