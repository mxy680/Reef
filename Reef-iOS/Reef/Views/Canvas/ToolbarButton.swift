//
//  ToolbarButton.swift
//  Reef
//

import SwiftUI

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isCustomIcon: Bool = false
    let action: () -> Void

    private static let barColor = Color(hex: 0x4E8A97)

    var body: some View {
        Button(action: action) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .frame(width: 32, height: 32, alignment: .center)
            .background(
                isSelected
                    ? Color.white.opacity(0.25)
                    : Self.barColor
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
                    .offset(x: 1.5, y: 1.5)
            )
        }
        .frame(width: 40, height: 40)
        .buttonStyle(.plain)
    }
}
