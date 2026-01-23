//
//  ContextualToolbar.swift
//  Reef
//
//  Contextual options tier that appears above the main toolbar
//

import SwiftUI

struct ContextualToolbar: View {
    let selectedTool: CanvasTool
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    let colorScheme: ColorScheme
    let hasSelection: Bool
    let onCut: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    private var penColors: [Color] {
        [
            colorScheme == .dark ? .white : .black,
            .vibrantTeal,
            .oceanMid,
            .deepSea
        ]
    }

    private let highlighterColors: [Color] = [
        Color(red: 1.0, green: 0.92, blue: 0.23),    // Yellow
        Color(red: 1.0, green: 0.6, blue: 0.8),      // Pink
        Color(red: 0.6, green: 0.9, blue: 0.6),      // Green
        Color(red: 0.6, green: 0.8, blue: 1.0),      // Blue
        Color(red: 1.0, green: 0.7, blue: 0.4)       // Orange
    ]

    var body: some View {
        Group {
            switch selectedTool {
            case .pen:
                penOptions
            case .highlighter:
                highlighterOptions
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

    // MARK: - Pen Options

    private var penOptions: some View {
        HStack(spacing: 12) {
            // Thickness slider with preview
            thicknessSlider(
                value: $penWidth,
                range: StrokeWidthRange.penMin...StrokeWidthRange.penMax
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Color swatches
            ForEach(penColors, id: \.self) { color in
                Button {
                    selectedPenColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    selectedPenColor == color ? Color.white : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: selectedPenColor == color ? color.opacity(0.3) : Color.clear,
                            radius: 4
                        )
                }
                .buttonStyle(.plain)
            }

            // Custom color picker
            ColorPicker("", selection: $selectedPenColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
        }
    }

    // MARK: - Highlighter Options

    private var highlighterOptions: some View {
        HStack(spacing: 12) {
            // Thickness slider with preview
            thicknessSlider(
                value: $highlighterWidth,
                range: StrokeWidthRange.highlighterMin...StrokeWidthRange.highlighterMax
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Color swatches
            ForEach(highlighterColors, id: \.self) { color in
                Button {
                    selectedHighlighterColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    selectedHighlighterColor == color ? Color.white : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: selectedHighlighterColor == color ? color.opacity(0.3) : Color.clear,
                            radius: 4
                        )
                }
                .buttonStyle(.plain)
            }

            // Custom color picker
            ColorPicker("", selection: $selectedHighlighterColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
        }
    }

    // MARK: - Eraser Options

    private var eraserOptions: some View {
        HStack(spacing: 12) {
            // Stroke eraser button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eraserType = .stroke
                }
            } label: {
                Image(systemName: "eraser.line.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(eraserType == .stroke ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .stroke ? Color.vibrantTeal.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            // Pixel eraser button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eraserType = .bitmap
                }
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(eraserType == .bitmap ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .bitmap ? Color.vibrantTeal.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            thicknessSlider(
                value: $eraserSize,
                range: StrokeWidthRange.eraserMin...StrokeWidthRange.eraserMax
            )
            .opacity(eraserType == .bitmap ? 1.0 : 0.35)
            .disabled(eraserType == .stroke)
            .animation(.easeInOut(duration: 0.2), value: eraserType)
        }
    }

    // MARK: - Thickness Slider

    private func thicknessSlider(value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 8) {
            // Small size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 4, height: 4)

            // Slider
            Slider(value: value, in: range)
                .accentColor(.vibrantTeal)
                .frame(width: 100)

            // Large size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 12, height: 12)

            // Current size preview
            Circle()
                .fill(Color.adaptiveText(for: colorScheme))
                .frame(width: min(value.wrappedValue, 16), height: min(value.wrappedValue, 16))
                .frame(width: 20, height: 20)
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
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.stroke),
            selectedPenColor: .constant(.black),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
            colorScheme: .light,
            hasSelection: false,
            onCut: {},
            onCopy: {},
            onDelete: {}
        )

        ContextualToolbar(
            selectedTool: .eraser,
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.bitmap),
            selectedPenColor: .constant(.black),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
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
