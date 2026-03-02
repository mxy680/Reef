//
//  CanvasToolbar.swift
//  Reef
//
//  Top toolbar with tool selection, color swatches, undo/redo
//

import SwiftUI

struct CanvasToolbar: View {
    let documentName: String
    let currentTool: DrawingTool
    let currentColor: StrokeColor
    let fingerDrawing: Bool
    let canUndo: Bool
    let canRedo: Bool
    let onClose: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSelectTool: (DrawingTool) -> Void
    let onSelectColor: (StrokeColor) -> Void
    let onToggleFingerDrawing: () -> Void

    private let presetColors: [StrokeColor] = [.black, .blue, .red, .green, .orange]

    var body: some View {
        HStack(spacing: 12) {
            // Close button
            actionButton(icon: "xmark", action: onClose)
                .accessibilityLabel("Close")

            Spacer()

            // Tool selector
            HStack(spacing: 2) {
                toolToggle(.pen, icon: "pencil.tip")
                toolToggle(.highlighter, icon: "highlighter")
                toolToggle(.eraser, icon: "eraser")
            }
            .padding(4)
            .background(ReefColors.gray100)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Color swatches (hidden for eraser)
            if currentTool != .eraser {
                HStack(spacing: 6) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(Color(color.uiColor))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(
                                        color == currentColor
                                            ? ReefColors.primary
                                            : Color.clear,
                                        lineWidth: 2.5
                                    )
                                    .padding(-3)
                            )
                            .contentShape(Circle())
                            .onTapGesture { onSelectColor(color) }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                actionButton(
                    icon: "arrow.uturn.backward",
                    enabled: canUndo,
                    action: onUndo
                )
                actionButton(
                    icon: "arrow.uturn.forward",
                    enabled: canRedo,
                    action: onRedo
                )
                fingerDrawingButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ReefColors.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ReefColors.gray200).frame(height: 1)
        }
    }

    // MARK: - Tool Toggle

    private func toolToggle(_ tool: DrawingTool, icon: String) -> some View {
        let isSelected = currentTool == tool
        return Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? ReefColors.white : ReefColors.gray600)
            .frame(width: 36, height: 36)
            .background(isSelected ? ReefColors.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { onSelectTool(tool) }
            .accessibilityLabel(tool.rawValue.capitalized)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Finger Drawing Toggle

    private var fingerDrawingButton: some View {
        Image(systemName: fingerDrawing ? "hand.draw.fill" : "hand.draw")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(fingerDrawing ? ReefColors.primary : ReefColors.gray600)
            .frame(width: 36, height: 36)
            .background(fingerDrawing ? ReefColors.primary.opacity(0.12) : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        fingerDrawing ? ReefColors.primary : ReefColors.gray400,
                        lineWidth: 1.5
                    )
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { onToggleFingerDrawing() }
            .accessibilityLabel(fingerDrawing ? "Disable finger drawing" : "Enable finger drawing")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Action Button

    private func actionButton(
        icon: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(enabled ? ReefColors.gray600 : ReefColors.gray400)
            .frame(width: 36, height: 36)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        enabled ? ReefColors.gray400 : ReefColors.gray200,
                        lineWidth: 1.5
                    )
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { if enabled { action() } }
            .accessibilityAddTraits(.isButton)
    }
}
