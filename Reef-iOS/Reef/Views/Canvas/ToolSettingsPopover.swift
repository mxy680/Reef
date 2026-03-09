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
    @State private var selectedIndex: Int? = nil

    // 6 columns x 5 rows = 30 colors
    private static let palette: [UIColor] = [
        // Row 1 — vivid primaries
        .black,
        UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
        UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1),
        UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
        .white,
        // Row 2 — warm
        UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
        UIColor(red: 0.95, green: 0.4, blue: 0.3, alpha: 1),
        UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1),
        UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1),
        UIColor(red: 0.85, green: 0.4, blue: 0.6, alpha: 1),
        UIColor(red: 0.7, green: 0.2, blue: 0.35, alpha: 1),
        // Row 3 — cool
        UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
        UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1),
        UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1),
        UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
        UIColor(red: 0.5, green: 0.8, blue: 0.3, alpha: 1),
        UIColor(red: 0.0, green: 0.5, blue: 0.35, alpha: 1),
        // Row 4 — purples & pastels
        UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1),
        UIColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1),
        UIColor(red: 0.8, green: 0.6, blue: 0.9, alpha: 1),
        UIColor(red: 0.95, green: 0.75, blue: 0.8, alpha: 1),
        UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1),
        UIColor(red: 0.75, green: 0.95, blue: 0.75, alpha: 1),
        // Row 5 — earth & muted
        UIColor(red: 0.6, green: 0.4, blue: 0.25, alpha: 1),
        UIColor(red: 0.75, green: 0.55, blue: 0.35, alpha: 1),
        UIColor(red: 0.55, green: 0.55, blue: 0.45, alpha: 1),
        UIColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1),
        UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1),
        UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 18) {
            Text("Pick a Color")
                .font(.system(size: 16, weight: .bold))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { index, color in
                    let isSelected = selectedIndex == index
                    Button {
                        selectedIndex = index
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ? ReefColors.black : ReefColors.gray200,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                                    .padding(isSelected ? -2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ReefColors.gray600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(ReefColors.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    if let index = selectedIndex {
                        onAdd(Self.palette[index])
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selectedIndex != nil ? ReefColors.primary : ReefColors.gray400)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(selectedIndex == nil)
            }
        }
        .padding(20)
        .frame(width: 280)
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
