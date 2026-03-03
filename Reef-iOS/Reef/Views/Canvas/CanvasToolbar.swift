//
//  CanvasToolbar.swift
//  Reef
//
//  Full-width top toolbar — close button, drawing tools, undo/redo
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: ToolbarColor
    let onClose: () -> Void

    /// Lighter teal pill behind the selected tool
    private static let selectedPill = Color.white.opacity(0.25)

    /// Divider between tool groups
    private static let dividerColor = Color.white.opacity(0.25)

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

                    // Color dots inline (when tool supports color)
                    if selectedTool.hasColorPalette {
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Self.dividerColor)
                            .frame(width: 1, height: 24)
                            .padding(.horizontal, 6)

                        colorDots
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }

                Spacer()

                // Balance spacer (same width as close button)
                Color.clear.frame(width: 36, height: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
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

    // MARK: - Color Dots

    private var colorDots: some View {
        HStack(spacing: 8) {
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
    }
}
