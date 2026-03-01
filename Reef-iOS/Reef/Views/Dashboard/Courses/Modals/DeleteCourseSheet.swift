import SwiftUI

struct DeleteCourseSheet: View {
    let course: Course
    let onConfirm: () -> Void
    let onClose: () -> Void

    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Delete \"\(course.name)\"?")
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)
                .multilineTextAlignment(.center)

            Text("Documents in this course will be unlinked, not deleted.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
                .padding(.top, 8)

            HStack(spacing: 10) {
                Button("Cancel") {
                    onClose()
                }
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)
                .buttonStyle(.plain)

                Button {
                    isDeleting = true
                    onConfirm()
                } label: {
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
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .presentationDetents([.height(200)])
        .presentationBackground(.white)
    }
}
