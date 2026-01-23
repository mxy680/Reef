//
//  CanvasToolbar.swift
//  Reef
//
//  Floating toolbar with pencil, eraser, color picker, and home button
//

import SwiftUI

// MARK: - Tool Types

enum CanvasTool: Equatable {
    case pen
    case eraser
}

// MARK: - Canvas Toolbar

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: Color
    let colorScheme: ColorScheme
    let onHomePressed: () -> Void

    // Theme colors for the color picker
    private let themeColors: [Color] = [
        .inkBlack,
        .vibrantTeal,
        .oceanMid,
        .deepSea
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Home button
            Button(action: onHomePressed) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 8)

            // Pencil tool
            Button {
                selectedTool = .pen
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedTool == .pen ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .background(
                        selectedTool == .pen ?
                            Color.vibrantTeal.opacity(0.15) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Eraser tool
            Button {
                selectedTool = .eraser
            } label: {
                Image(systemName: "eraser.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedTool == .eraser ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .background(
                        selectedTool == .eraser ?
                            Color.vibrantTeal.opacity(0.15) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Divider before colors
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 8)

            // Inline color options
            HStack(spacing: 8) {
                ForEach(themeColors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        selectedTool = .pen  // Switch to pen when selecting a color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedColor == color ? Color.white : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        Color.adaptiveText(for: colorScheme).opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(colorScheme == .dark ? Color.deepSea : Color.lightGrayBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    CanvasToolbar(
        selectedTool: .constant(.pen),
        selectedColor: .constant(.inkBlack),
        colorScheme: .light,
        onHomePressed: {}
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
