@preconcurrency import Supabase
import SwiftUI

struct DocumentUploadSheet: View {
    let filename: String
    let onConfirm: (String?, Bool) -> Void
    let onClose: () -> Void

    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var selectedCourseId: String?
    @State private var reconstruct = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upload Document")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)

            Text(filename)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.top, 6)

            // Course picker
            Text("Course")
                .font(.epilogue(13, weight: .bold))
                .tracking(-0.04 * 13)
                .foregroundStyle(ReefColors.gray600)
                .padding(.top, 24)

            if isLoading {
                Text("Loading courses...")
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray500)
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
                                    .foregroundStyle(ReefColors.gray600)
                                Text(course.name)
                                    .font(.epilogue(14, weight: .semiBold))
                                    .tracking(-0.04 * 14)
                                    .foregroundStyle(ReefColors.black)
                            }
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
                .padding(.top, 8)
            }

            // Reconstruct toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconstruct document")
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.black)

                    Text("Extracts questions and enables tutor mode")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(ReefColors.gray500)
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
                    .foregroundStyle(ReefColors.gray600)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
                    .accessibilityAddTraits(.isButton)

                Text("Upload")
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
                        onConfirm(selectedCourseId, reconstruct)
                    }
                    .accessibilityAddTraits(.isButton)
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
            do {
                courses = try await supabase
                    .from("courses")
                    .select()
                    .order("created_at")
                    .execute()
                    .value
            } catch {
                // Silently fail — shows "No course" only
            }
            isLoading = false
        }
    }
}
