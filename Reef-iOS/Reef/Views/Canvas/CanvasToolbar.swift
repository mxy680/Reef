//
//  CanvasToolbar.swift
//  Reef
//
//  Two-row toolbar — question tabs + drawing tools (GoodNotes style)
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: ToolbarColor
    let onClose: () -> Void

    @State private var selectedQuestion = 1
    @State private var tutorModeOn = false

    private static let barColor = Color(hex: 0x4E8A97)
    private static let selectedPill = Color.white.opacity(0.25)
    private static let dividerColor = Color.white.opacity(0.25)
    private static let questionCount = 10

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // ── Row 1: Question Navigation ──
                questionRow

                // ── Row 2: Drawing Tools ──
                toolRow
            }
            .padding(.top, safeAreaTop)
            .background(Self.barColor)

            // Color palette strip — slides in below the bar
            if selectedTool.hasColorPalette {
                ColorPaletteStrip(selectedColor: $selectedColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTool.hasColorPalette)
    }

    // MARK: - Row 1: Question Tabs

    private var questionRow: some View {
        HStack(spacing: 0) {
            // Home button
            iconButton("house.fill", size: 16)
                .onTapGesture { onClose() }

            Spacer().frame(width: 12)

            // Question tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(1...Self.questionCount, id: \.self) { q in
                        if q > 1 {
                            divider
                        }
                        questionTab(q)
                    }
                }
            }

            Spacer()

            // Tutor Mode toggle
            HStack(spacing: 8) {
                Text("Tutor Mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Toggle("", isOn: $tutorModeOn)
                    .labelsHidden()
                    .tint(.white.opacity(0.4))
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func questionTab(_ number: Int) -> some View {
        let isSelected = selectedQuestion == number
        return Text("Q\(number)")
            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Self.selectedPill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { selectedQuestion = number }
    }

    // MARK: - Row 2: Tool Bar

    private var toolRow: some View {
        HStack(spacing: 0) {
            // Undo / Redo
            actionButton(icon: "arrow.uturn.backward")
            actionButton(icon: "arrow.uturn.forward")

            divider

            // Drawing tools (selectable)
            ForEach(CanvasTool.allCases, id: \.self) { tool in
                toolButton(tool)
            }

            divider

            // Ruler, copy, paste (static)
            iconButton("ruler.fill", size: 18)
            iconButton("doc.on.doc", size: 16)
            iconButton("doc.on.clipboard", size: 16)

            divider

            // Mic with orange badge + more
            micButton
            iconButton("ellipsis", size: 18)

            Spacer()

            // Trash + dark mode
            iconButton("trash", size: 16)
            iconButton("moon", size: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - Buttons

    private func toolButton(_ tool: CanvasTool) -> some View {
        let isSelected = selectedTool == tool
        return Image(systemName: tool.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
            .frame(width: 40, height: 40)
            .background(isSelected ? Self.selectedPill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedTool = tool
                }
            }
    }

    private func actionButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }

    private func iconButton(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }

    private var micButton: some View {
        Image(systemName: "mic")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 40, height: 40)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: -6, y: 6)
            }
            .contentShape(Rectangle())
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Self.dividerColor)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 6)
    }
}

// MARK: - Color Palette Strip

private struct ColorPaletteStrip: View {
    @Binding var selectedColor: ToolbarColor

    private static let stripColor = Color(hex: 0x5B9EAD).opacity(0.3)

    var body: some View {
        HStack(spacing: 12) {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Self.stripColor)
    }
}
