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
    let onAction: (DocumentAction) -> Void

    @State private var isPressed = false

    private var borderColor: Color {
        document.status == .failed ? Color(hex: 0xE57373) : ReefColors.gray500
    }

    var body: some View {
        Button {
            if document.status == .completed {
                onAction(.open)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                DocumentThumbnailView(status: document.status, thumbnailURL: thumbnailURL)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                // Info
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
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
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
            .opacity(document.status == .processing ? 0.85 : 1)
        }
        .buttonStyle(.plain)
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
                menuButton
            }
            .padding(8)
        }
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
        Button {
            onAction(.retry)
        } label: {
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
        }
        .buttonStyle(.plain)
    }

    private var menuButton: some View {
        Menu {
            Button { onAction(.rename) } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button { onAction(.download) } label: {
                Label("Download", systemImage: "arrow.down.doc")
            }
            Button { onAction(.moveToCourse) } label: {
                Label("Move to Course", systemImage: "folder")
            }
            Button { onAction(.duplicate) } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button { onAction(.share) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button { onAction(.viewDetails) } label: {
                Label("View Details", systemImage: "info.circle")
            }
            Divider()
            Button(role: .destructive) { onAction(.delete) } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
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
        }
        .menuStyle(.borderlessButton)
    }
}
