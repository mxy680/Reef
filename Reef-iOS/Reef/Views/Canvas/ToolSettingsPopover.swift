//
//  ToolSettingsPopover.swift
//  Reef
//
//  Color and thickness picker popover for drawing tools
//

import SwiftUI

struct ToolSettingsPopover: View {
    @Binding var selectedColor: UIColor
    @Binding var lineWidth: CGFloat
    @Binding var customColors: [UIColor]
    @State private var showColorPicker = false

    /// 3 defaults + user-added colors
    private var allColors: [UIColor] {
        Self.defaultColors + customColors
    }

    static let defaultColors: [UIColor] = [
        .black,
        UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
        UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
    ]

    /// Max visible without scrolling
    private static let visibleCount = 5

    var body: some View {
        VStack(spacing: 16) {
            // Color row
            colorRow

            // Thickness slider with preview dot
            HStack(spacing: 10) {
                // Thin indicator
                Circle()
                    .fill(Color(selectedColor))
                    .frame(width: 4, height: 4)

                Slider(value: $lineWidth, in: 0.5...8.0)
                    .tint(Color(selectedColor))

                // Live-size preview dot
                Circle()
                    .fill(Color(selectedColor))
                    .frame(width: lineWidth * 2, height: lineWidth * 2)
                    .frame(width: 18, height: 18)
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(
            ZStack {
                // 3D shadow
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.black)
                    .offset(x: 4, y: 4)

                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.white)

                // Border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReefColors.black, lineWidth: 2)
            }
        )
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(onColorPicked: { color in
                customColors.append(color)
                selectedColor = color
            })
            .presentationDetents([.height(200)])
        }
    }

    // MARK: - Color Row

    @ViewBuilder
    private var colorRow: some View {
        // +1 for the add button
        let totalItems = allColors.count + 1
        let needsScroll = totalItems > Self.visibleCount

        if needsScroll {
            ScrollView(.horizontal, showsIndicators: false) {
                colorButtons
            }
        } else {
            colorButtons
        }
    }

    private var colorButtons: some View {
        HStack(spacing: 12) {
            ForEach(Array(allColors.enumerated()), id: \.offset) { _, color in
                colorCircle(color: color, isSelected: selectedColor == color)
            }

            // Add color button
            Button {
                showColorPicker = true
            } label: {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(ReefColors.gray400, lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ReefColors.gray400)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func colorCircle(color: UIColor, isSelected: Bool) -> some View {
        Button {
            selectedColor = color
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? ReefColors.black : Color.clear,
                            lineWidth: isSelected ? 2 : 0
                        )
                        .padding(-2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Picker Sheet

private struct ColorPickerSheet: View {
    let onColorPicked: (UIColor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedColor = Color.blue

    var body: some View {
        VStack(spacing: 20) {
            ColorPicker("Pick a color", selection: $pickedColor, supportsOpacity: false)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 20)

            Button {
                onColorPicked(UIColor(pickedColor))
                dismiss()
            } label: {
                Text("Add Color")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(ReefColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
    }
}
