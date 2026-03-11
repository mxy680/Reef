//
//  PageMenuView.swift
//  Reef
//

import SwiftUI

// MARK: - Page Menu View

struct PageMenuView: View {
    let onAction: (PageAction) -> Void
    var canUndo: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow(systemIcon: "doc.fill.badge.plus", label: "Add Page to End") {
                onAction(.addBlankAtEnd)
            }
            menuRow(systemIcon: "doc.on.doc.fill", label: "Add Page After This") {
                onAction(.addBlankAfterCurrent)
            }
            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            menuRow(systemIcon: "xmark.bin.fill", label: "Delete This Page", isDestructive: true) {
                onAction(.deleteCurrentPage)
            }
            menuRow(systemIcon: "trash.fill", label: "Delete All Pages", isDestructive: true) {
                onAction(.deleteAllPages)
            }
            if canUndo {
                Divider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 2)
                menuRow(systemIcon: "arrow.uturn.backward", label: "Undo") {
                    onAction(.undo)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: 230)
    }

    private func menuRow(systemIcon: String, label: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundColor(isDestructive ? .red : ReefColors.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
