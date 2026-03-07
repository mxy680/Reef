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

    // Proportional padding scaled to card height for consistent spacing across iPad sizes
    private var thumbPad: CGFloat {
        guard let h = cardHeight else { return 8 }
        return max(6, min(12, h * 0.035))
    }

    private var footerPadH: CGFloat {
        guard let h = cardHeight else { return 12 }
        return max(10, min(16, h * 0.05))
    }

    private var footerPadTop: CGFloat {
        guard let h = cardHeight else { return 10 }
        return max(8, min(14, h * 0.045))
    }

    private var footerBottomPad: CGFloat {
        guard let h = cardHeight else { return 16 }
        return max(12, min(22, h * 0.075))
    }

    private var borderColor: Color {
        document.status == .failed ? Color(hex: 0xE57373) : ReefColors.gray500
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail — flexible, fills remaining space
            DocumentThumbnailView(status: document.status, thumbnailURL: thumbnailURL)
                .padding(.horizontal, thumbPad)
                .padding(.top, thumbPad)

            // Divider
            Rectangle()
                .fill(ReefColors.gray200)
                .frame(height: 1)
                .padding(.top, thumbPad)
                .layoutPriority(1)

            // Info footer — natural height, priority sizing
            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayName)
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(document.statusLabel)
                    .font(.epilogue(11, weight: .medium))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, footerPadH)
            .padding(.top, footerPadTop)
            .padding(.bottom, footerBottomPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(height: cardHeight)
        .background(ReefColors.white)
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
        switch document.status {
        case .processing: ReefColors.primary
        case .failed: ReefColors.error
        case .completed: ReefColors.gray500
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
        Image(systemName: "ellipsis")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(ReefColors.gray500)
            .frame(width: 28, height: 28)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ReefColors.gray400, lineWidth: 1.5)
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
        VStack(alignment: .leading, spacing: 0) {
            dropdownItem("Rename", action: .rename)
            dropdownItem("Download", action: .download)
            dropdownItem("Move to Course", action: .moveToCourse)
            dropdownItem("Duplicate", action: .duplicate)
            dropdownItem("Share", action: .share)
            dropdownItem("View Details", action: .viewDetails)

            Rectangle()
                .fill(ReefColors.gray100)
                .frame(height: 1)
                .padding(.vertical, 2)

            dropdownItem("Delete", action: .delete, isDestructive: true)
        }
        .background(ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ReefColors.gray500, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.gray500)
                .offset(x: 3, y: 3)
        )
        .fixedSize(horizontal: true, vertical: true)
        .frame(minWidth: 160, alignment: .trailing)
    }

    private func dropdownItem(_ label: String, action: DocumentAction, isDestructive: Bool = false) -> some View {
        Text(label)
            .font(.epilogue(13, weight: .semiBold))
            .tracking(-0.04 * 13)
            .foregroundStyle(isDestructive ? Color(hex: 0xC62828) : ReefColors.black)
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
