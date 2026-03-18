import SwiftUI

// MARK: - Tutor Hint Popover (placeholder for future LaTeX rendering)

struct CanvasTutorHintContent: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReefColors.black)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(text)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundColor(ReefColors.gray600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
    }
}
