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
        ZStack {
            mainPopover

            if showColorPicker {
                colorPickerPopup
            }
        }
        .animation(.spring(duration: 0.2), value: showColorPicker)
    }

    // MARK: - Main Popover

    private var mainPopover: some View {
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
        .background(popoverBackground)
    }

    // MARK: - Color Picker Popup

    private var colorPickerPopup: some View {
        ColorPickerPopup(
            onColorPicked: { color in
                customColors.append(color)
                selectedColor = color
                showColorPicker = false
            },
            onDismiss: { showColorPicker = false }
        )
        .offset(y: 120)
        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
    }

    // MARK: - Color Row

    @ViewBuilder
    private var colorRow: some View {
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
                showColorPicker.toggle()
            } label: {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(
                                showColorPicker ? ReefColors.primary : ReefColors.gray400,
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(
                                showColorPicker ? ReefColors.primary : ReefColors.gray400
                            )
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

    // MARK: - Shared Background

    private var popoverBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(ReefColors.black)
                .offset(x: 4, y: 4)

            RoundedRectangle(cornerRadius: 12)
                .fill(ReefColors.white)

            RoundedRectangle(cornerRadius: 12)
                .stroke(ReefColors.black, lineWidth: 2)
        }
    }
}

// MARK: - Color Picker Popup

private struct ColorPickerPopup: View {
    let onColorPicked: (UIColor) -> Void
    let onDismiss: () -> Void
    @State private var pickedColor = Color(UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1))

    private let presetColors: [UIColor] = [
        UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
        UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1),
        UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1),
        UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1),
        UIColor(red: 0.85, green: 0.4, blue: 0.6, alpha: 1),
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Quick presets
            HStack(spacing: 10) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    Button {
                        onColorPicked(color)
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Divider
            Rectangle()
                .fill(ReefColors.gray200)
                .frame(height: 1)

            // Custom color picker
            HStack(spacing: 12) {
                ColorPicker("", selection: $pickedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)

                // Preview circle
                Circle()
                    .fill(pickedColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(ReefColors.gray200, lineWidth: 1)
                    )

                Spacer()

                Button {
                    onColorPicked(UIColor(pickedColor))
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(ReefColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.black)
                    .offset(x: 4, y: 4)

                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.white)

                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReefColors.black, lineWidth: 2)
            }
        )
    }
}
