//
//  CanvasToolbar.swift
//  Reef
//
//  Top bar with close button and document title
//

import SwiftUI

struct CanvasToolbar: View {
    let documentName: String
    let onClose: () -> Void

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        HStack {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ReefColors.gray600)
                .frame(width: 36, height: 36)
                .background(ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ReefColors.gray400, lineWidth: 1.5)
                )
                .compositingGroup()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)

            Spacer()

            Text(documentName)
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(ReefColors.black)
                .lineLimit(1)

            Spacer()

            // Invisible spacer to balance the close button
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .padding(.top, safeAreaTop)
        .background(ReefColors.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ReefColors.gray200).frame(height: 1)
        }
    }
}
