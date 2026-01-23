//
//  ContextualToolbar.swift
//  Reef
//
//  Contextual options tier that appears above the main toolbar
//

import SwiftUI

struct ContextualToolbar: View {
    let selectedTool: CanvasTool
    @Binding var penWidth: StrokeWidth
    @Binding var highlighterWidth: StrokeWidth
    @Binding var eraserSize: EraserSize
    @Binding var selectedColor: Color
    let colorScheme: ColorScheme
    let hasSelection: Bool
    let onCut: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    private let themeColors: [Color] = [
        .inkBlack,
        .vibrantTeal,
        .oceanMid,
        .deepSea
    ]

    var body: some View {
        Group {
            switch selectedTool {
            case .pen:
                penHighlighterOptions(width: $penWidth)
            case .highlighter:
                penHighlighterOptions(width: $highlighterWidth)
            case .eraser:
                eraserOptions
            case .lasso:
                if hasSelection {
                    lassoOptions
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color.deepOcean : Color.lightGrayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.15) : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.15),
                    radius: colorScheme == .dark ? 12 : 8,
                    x: 0,
                    y: 4
                )
        )
    }

    // MARK: - Pen/Highlighter Options

    private func penHighlighterOptions(width: Binding<StrokeWidth>) -> some View {
        HStack(spacing: 12) {
            // Stroke width presets
            ForEach(StrokeWidth.allCases, id: \.self) { strokeWidth in
                Button {
                    width.wrappedValue = strokeWidth
                } label: {
                    Circle()
                        .fill(Color.adaptiveText(for: colorScheme))
                        .frame(width: strokeWidth.displaySize, height: strokeWidth.displaySize)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .strokeBorder(
                                    width.wrappedValue == strokeWidth ? Color.vibrantTeal : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Color swatches
            ForEach(themeColors, id: \.self) { color in
                Button {
                    selectedColor = color
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
                        .shadow(
                            color: selectedColor == color ? color.opacity(0.3) : Color.clear,
                            radius: 4
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Eraser Options

    private var eraserOptions: some View {
        HStack(spacing: 12) {
            ForEach(EraserSize.allCases, id: \.self) { size in
                Button {
                    eraserSize = size
                } label: {
                    Circle()
                        .fill(Color.adaptiveText(for: colorScheme))
                        .frame(width: size.displaySize, height: size.displaySize)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .strokeBorder(
                                    eraserSize == size ? Color.vibrantTeal : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Lasso Options

    private var lassoOptions: some View {
        HStack(spacing: 16) {
            Button(action: onCut) {
                Label("Cut", systemImage: "scissors")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }
            .buttonStyle(.plain)

            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.deleteRed)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ContextualToolbar(
            selectedTool: .pen,
            penWidth: .constant(.medium),
            highlighterWidth: .constant(.medium),
            eraserSize: .constant(.medium),
            selectedColor: .constant(.inkBlack),
            colorScheme: .light,
            hasSelection: false,
            onCut: {},
            onCopy: {},
            onDelete: {}
        )

        ContextualToolbar(
            selectedTool: .eraser,
            penWidth: .constant(.medium),
            highlighterWidth: .constant(.medium),
            eraserSize: .constant(.medium),
            selectedColor: .constant(.inkBlack),
            colorScheme: .dark,
            hasSelection: false,
            onCut: {},
            onCopy: {},
            onDelete: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
