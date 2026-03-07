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
    var onAddColorTapped: () -> Void = {}

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
            colorRow

            // Thickness slider with preview dot
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(selectedColor))
                    .frame(width: 4, height: 4)

                Slider(value: $lineWidth, in: 0.5...8.0)
                    .tint(Color(selectedColor))

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
            Button(action: onAddColorTapped) {
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

// MARK: - Add Color Popup

struct AddColorPopup: View {
    let onAdd: (UIColor) -> Void
    let onDismiss: () -> Void
    @State private var pickedColor = Color.orange

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Color")
                .font(.system(size: 17, weight: .bold))

            ColorPicker("Select color", selection: $pickedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 200, height: 200)

            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ReefColors.gray600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ReefColors.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    onAdd(UIColor(pickedColor))
                } label: {
                    Text("Add")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ReefColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: 300)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ReefColors.black)
                    .offset(x: 4, y: 4)

                RoundedRectangle(cornerRadius: 16)
                    .fill(ReefColors.white)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(ReefColors.black, lineWidth: 2)
            }
        )
    }
}
