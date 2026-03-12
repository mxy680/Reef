//
//  ToolbarButton.swift
//  Reef
//

import SwiftUI

// MARK: - Toolbar Button (Row 2 — drawing tools, utilities, etc.)

struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isCustomIcon: Bool = false
    let action: () -> Void

    private static let barColor = Color(hex: 0x4E8A97)
    private static let borderColor = ReefColors.gray500

    @State private var isPressed = false

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
                    .stroke(Self.borderColor, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Self.borderColor)
                    .offset(x: isPressed ? 0 : 3, y: isPressed ? 0 : 3)
            )
            .offset(x: isPressed ? 3 : 0, y: isPressed ? 3 : 0)
        }
        .frame(width: 40, height: 40)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = false }
                }
        )
    }
}

// MARK: - Small 3D Button (Row 1 — home, retry, next)

struct Toolbar3DSmallButton: View {
    let icon: String
    var isCustomIcon: Bool = false
    let action: () -> Void

    private static let barColor = Color(hex: 0x4E8A97)
    private static let borderColor = ReefColors.gray500

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(width: 26, height: 22)
            .background(Self.barColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Self.borderColor, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Self.borderColor)
                    .offset(x: isPressed ? 0 : 2, y: isPressed ? 0 : 2)
            )
            .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = false }
                }
        )
    }
}
