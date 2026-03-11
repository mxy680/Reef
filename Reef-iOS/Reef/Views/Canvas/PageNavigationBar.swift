import SwiftUI

struct PageNavigationBar: View {
    @Environment(ThemeManager.self) private var theme
    let currentPage: Int
    let pageCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        let dark = theme.isDarkMode
        HStack {
            navButton(icon: "chevron.left", enabled: currentPage > 0, dark: dark, action: onPrevious)

            Spacer()

            Text("Page \(currentPage + 1) of \(pageCount)")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

            Spacer()

            navButton(icon: "chevron.right", enabled: currentPage < pageCount - 1, dark: dark, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
        .overlay(alignment: .top) {
            Rectangle().fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray200).frame(height: 1)
        }
    }

    private func navButton(icon: String, enabled: Bool, dark: Bool, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(enabled ? (dark ? ReefColors.DashboardDark.text : ReefColors.black) : (dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400))
            .frame(width: 36, height: 36)
            .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(enabled ? (dark ? ReefColors.DashboardDark.border : ReefColors.gray400) : (dark ? ReefColors.DashboardDark.divider : ReefColors.gray200), lineWidth: 1.5)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                if enabled { action() }
            }
            .accessibilityAddTraits(.isButton)
    }
}
