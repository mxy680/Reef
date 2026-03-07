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

    private static let colors: [(String, UIColor)] = [
        ("Black", .black),
        ("Blue", UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)),
        ("Red", UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)),
        ("Green", UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)),
        ("Orange", UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1)),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Color row
            HStack(spacing: 12) {
                ForEach(Self.colors, id: \.0) { name, color in
                    let isSelected = selectedColor == color
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

            // Thickness slider
            VStack(spacing: 8) {
                HStack {
                    // Thin line indicator
                    Circle()
                        .fill(Color(selectedColor))
                        .frame(width: 4, height: 4)

                    Slider(value: $lineWidth, in: 0.5...8.0)
                        .tint(Color(selectedColor))

                    // Thick line indicator
                    Circle()
                        .fill(Color(selectedColor))
                        .frame(width: 14, height: 14)
                }

                // Preview stroke
                RoundedRectangle(cornerRadius: lineWidth / 2)
                    .fill(Color(selectedColor))
                    .frame(height: lineWidth)
                    .frame(maxWidth: .infinity)
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
    }
}
