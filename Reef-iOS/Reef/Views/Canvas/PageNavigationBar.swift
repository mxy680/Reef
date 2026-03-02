import SwiftUI

struct PageNavigationBar: View {
    let currentPage: Int
    let pageCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            navButton(icon: "chevron.left", enabled: currentPage > 0, action: onPrevious)

            Spacer()

            Text("Page \(currentPage + 1) of \(pageCount)")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.gray600)

            Spacer()

            navButton(icon: "chevron.right", enabled: currentPage < pageCount - 1, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ReefColors.white)
        .overlay(alignment: .top) {
            Rectangle().fill(ReefColors.gray200).frame(height: 1)
        }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(enabled ? ReefColors.black : ReefColors.gray400)
            .frame(width: 36, height: 36)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(enabled ? ReefColors.gray400 : ReefColors.gray200, lineWidth: 1.5)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                if enabled { action() }
            }
            .accessibilityAddTraits(.isButton)
    }
}
