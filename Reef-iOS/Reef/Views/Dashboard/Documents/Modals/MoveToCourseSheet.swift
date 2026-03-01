@preconcurrency import Supabase
import SwiftUI

struct Course: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let emoji: String
    let color: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case emoji
        case color
        case createdAt = "created_at"
    }
}

struct MoveToCourseSheet: View {
    let document: Document
    let onConfirm: (String?) -> Void
    let onClose: () -> Void

    @State private var courses: [Course] = []
    @State private var isLoading = true

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
                VStack(spacing: 6) {
                    // Remove from course option
                    if document.courseId != nil {
                        Button {
                            onConfirm(nil)
                        } label: {
                            HStack(spacing: 10) {
                                Text("Remove from course")
                                    .font(.epilogue(13, weight: .semiBold))
                                    .tracking(-0.04 * 13)
                                    .foregroundStyle(ReefColors.gray600)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .foregroundStyle(ReefColors.gray400)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(courses) { course in
                        let isCurrent = document.courseId == course.id

                        Button {
                            onConfirm(course.id)
                        } label: {
                            HStack(spacing: 10) {
                                Text(course.emoji)
                                    .font(.system(size: 16))

                                Text(course.name)
                                    .font(.epilogue(13, weight: .semiBold))
                                    .tracking(-0.04 * 13)
                                    .foregroundStyle(ReefColors.black)

                                Spacer()

                                if isCurrent {
                                    Text("Current")
                                        .font(.epilogue(11, weight: .bold))
                                        .tracking(-0.04 * 11)
                                        .foregroundStyle(ReefColors.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isCurrent ? ReefColors.primary.opacity(0.08) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isCurrent ? ReefColors.primary : ReefColors.gray400,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    onClose()
                }
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
            }
            .padding(.top, 20)
        }
        .padding(28)
        .presentationDetents([.medium])
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
