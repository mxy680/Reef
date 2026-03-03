//
//  CanvasToolbar.swift
//  Reef
//
//  Top toolbar — close button, drawing tools, undo/redo
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: ToolbarColor
    let onClose: () -> Void

    /// Soft teal — primary at 85% over a slightly darkened base
    private static let barColor = Color(hex: 0x4E8A97)

    /// Lighter teal pill behind the selected tool
    private static let selectedPill = Color.white.opacity(0.25)

    /// Divider between tool groups
    private static let dividerColor = Color.white.opacity(0.25)

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main bar
            HStack(spacing: 0) {
                // Close button
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }
                    .accessibilityLabel("Close")
                    .accessibilityAddTraits(.isButton)

                Spacer()

                // Drawing tools — centered
                HStack(spacing: 2) {
                    ForEach(CanvasTool.allCases, id: \.self) { tool in
                        toolButton(tool)
                    }

                    // Divider
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Self.dividerColor)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 6)

                    // Undo
                    actionButton(icon: "arrow.uturn.backward")
                    // Redo
                    actionButton(icon: "arrow.uturn.forward")
                }

                Spacer()

                // Balance spacer (same width as close button)
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.top, safeAreaTop)

            // Color palette strip — slides in below the bar
            if selectedTool.hasColorPalette {
                ColorPaletteStrip(selectedColor: $selectedColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Self.barColor)
        .animation(.easeInOut(duration: 0.2), value: selectedTool.hasColorPalette)
    }

    // MARK: - Tool Button

    private func toolButton(_ tool: CanvasTool) -> some View {
        let isSelected = selectedTool == tool
        return Image(systemName: tool.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
            .frame(width: 44, height: 44)
            .background(isSelected ? Self.selectedPill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedTool = tool
                }
            }
    }

    // MARK: - Action Button (undo/redo)

    private func actionButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

// MARK: - Color Palette Strip

private struct ColorPaletteStrip: View {
    @Binding var selectedColor: ToolbarColor

    /// Slightly darker teal for the color strip
    private static let stripColor = Color(hex: 0x457A86)

    var body: some View {
        HStack(spacing: 12) {
            ForEach(ToolbarColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(
                                selectedColor == color ? .white : .clear,
                                lineWidth: 2.5
                            )
                            .frame(width: 30, height: 30)
                    )
                    .contentShape(Circle().inset(by: -6))
                    .onTapGesture { selectedColor = color }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Self.stripColor)
    }
}
