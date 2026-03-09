import SwiftUI

enum DocumentAction {
    case rename
    case download
    case moveToCourse
    case duplicate
    case share
    case viewDetails
    case delete
    case retry
    case open
}

struct DocumentCardView: View {
    let document: Document
    let thumbnailURL: URL?
    let index: Int
    var cardHeight: CGFloat? = nil
    let onAction: (DocumentAction) -> Void

    @State private var isPressed = false
    @State private var showMenu = false
    @Environment(ThemeManager.self) private var theme

    private var borderColor: Color {
        let dark = theme.isDarkMode
        return document.status == .failed ? Color(hex: 0xE57373) : (dark ? ReefColors.DashboardDark.shadow : ReefColors.gray500)
    }

    var body: some View {
        let dark = theme.isDarkMode
        GeometryReader { geo in
            let pad: CGFloat = 10
            let footerH = max(50, geo.size.height * 0.18)
            let thumbnailH = geo.size.height - footerH - 1

            VStack(spacing: 0) {
                // Thumbnail — explicit height from geometry
                DocumentThumbnailView(status: document.status, thumbnailURL: thumbnailURL)
                    .frame(height: thumbnailH)
                    .clipped()

                // Divider
                Rectangle()
                    .fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray200)
                    .frame(height: 1)

                // Footer — GeometryReader + .position() for guaranteed centering
                GeometryReader { footerGeo in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.displayName)
                                .font(.epilogue(13, weight: .bold))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(document.statusLabel)
                                .font(.epilogue(11, weight: .medium))
                                .tracking(-0.04 * 11)
                                .foregroundStyle(statusColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, pad)
                    .frame(width: footerGeo.size.width)
                    .position(x: footerGeo.size.width / 2, y: footerGeo.size.height / 2)
                }
                .frame(height: footerH)
            }
        }
        .frame(height: cardHeight)
        .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(borderColor)
                .offset(x: isPressed ? 0 : 4, y: isPressed ? 0 : 4)
        )
        .offset(x: isPressed ? 4 : 0, y: isPressed ? 4 : 0)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture {
            if document.status == .completed {
                onAction(.open)
            }
        }
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard document.status == .completed else { return }
                    withAnimation(.spring(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = false }
                }
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if document.status == .failed {
                    errorButton
                }
                menuTrigger
            }
            .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            if showMenu {
                dropdownMenu
                    .padding(.top, 44)
                    .padding(.trailing, 8)
                    .transition(
                        .scale(scale: 0.95, anchor: .topTrailing)
                        .combined(with: .opacity)
                    )
            }
        }
        .zIndex(showMenu ? 1 : 0)
        .fadeUp(index: index)
    }

    private var statusColor: Color {
        let dark = theme.isDarkMode
        switch document.status {
        case .processing: return ReefColors.primary
        case .failed: return ReefColors.error
        case .completed: return dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500
        }
    }

    private var errorButton: some View {
        Image(systemName: "exclamationmark.circle")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: 0xC62828))
            .frame(width: 28, height: 28)
            .background(Color(hex: 0xFFF5F5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0xE57373), lineWidth: 1.5)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                onAction(.retry)
            }
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Menu Trigger

    private var menuTrigger: some View {
        let dark = theme.isDarkMode
        return Image(systemName: "ellipsis")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
            .frame(width: 28, height: 28)
            .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400, lineWidth: 1.5)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.15)) {
                    showMenu.toggle()
                }
            }
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Dropdown Menu

    private var dropdownMenu: some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 0) {
            dropdownItem("Rename", action: .rename)
            dropdownItem("Download", action: .download)
            dropdownItem("Move to Course", action: .moveToCourse)
            dropdownItem("Duplicate", action: .duplicate)
            dropdownItem("Share", action: .share)
            dropdownItem("View Details", action: .viewDetails)

            Rectangle()
                .fill(dark ? ReefColors.DashboardDark.divider : ReefColors.gray100)
                .frame(height: 1)
                .padding(.vertical, 2)

            dropdownItem("Delete", action: .delete, isDestructive: true)
        }
        .background(dark ? ReefColors.DashboardDark.cardElevated : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dark ? ReefColors.DashboardDark.shadow : ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 160, alignment: .trailing)
    }

    private func dropdownItem(_ label: String, action: DocumentAction, isDestructive: Bool = false) -> some View {
        let dark = theme.isDarkMode
        return Text(label)
            .font(.epilogue(13, weight: .semiBold))
            .tracking(-0.04 * 13)
            .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.15)) { showMenu = false }
                onAction(action)
            }
            .accessibilityAddTraits(.isButton)
    }
}
