//
//  CanvasToolbar.swift
//  Reef
//
//  Two-row toolbar — question tabs + drawing tools (GoodNotes style)
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    let onClose: () -> Void

    @State private var selectedQuestion = 1
    @State private var tutorModeOn = false

    private static let barColor = Color(hex: 0x4E8A97)
    private static let selectedPill = Color.white.opacity(0.25)
    private static let dividerColor = Color.white.opacity(0.3)
    private static let questionCount = 10

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Row 1: Question Navigation ──
            questionRow

            // ── Row 2: Drawing Tools ──
            toolRow
        }
        .padding(.top, safeAreaTop)
        .background(Self.barColor)
    }

    // MARK: - Row 1: Question Tabs

    private var questionRow: some View {
        HStack(spacing: 0) {
            // Home button
            Image(systemName: "house.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            // Question tabs with dividers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(1...Self.questionCount, id: \.self) { q in
                        if q > 1 {
                            verticalDivider
                        }
                        questionTab(q)
                    }
                }
            }

            Spacer()

            // Tutor Mode toggle
            HStack(spacing: 6) {
                Text("Tutor Mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Toggle("", isOn: $tutorModeOn)
                    .labelsHidden()
                    .tint(.white.opacity(0.4))
                    .scaleEffect(0.7)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private func questionTab(_ number: Int) -> some View {
        let isSelected = selectedQuestion == number
        return Text("Q\(number)")
            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 8).fill(Self.selectedPill)
                    : nil
            )
            .contentShape(Rectangle())
            .onTapGesture { selectedQuestion = number }
    }

    // MARK: - Row 2: Tool Bar (centered layout)

    private var toolRow: some View {
        HStack(spacing: 0) {
            // Left: Undo / Redo
            HStack(spacing: 0) {
                actionButton(icon: "arrow.uturn.backward")
                actionButton(icon: "arrow.uturn.forward")
            }

            verticalDivider

            Spacer()

            // Center: Drawing tools + utility tools + mic/more
            HStack(spacing: 0) {
                // Drawing tools (selectable)
                ForEach(CanvasTool.allCases, id: \.self) { tool in
                    toolButton(tool)
                }

                verticalDivider

                // Ruler, copy, paste (static)
                staticButton("ruler.fill")
                staticButton("doc.on.doc")
                staticButton("doc.on.clipboard")

                verticalDivider

                // Mic with orange badge + more
                micButton
                staticButton("ellipsis")
            }

            Spacer()

            // Right: Trash + dark mode
            HStack(spacing: 0) {
                staticButton("trash")
                staticButton("moon")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    // MARK: - Buttons

    private func toolButton(_ tool: CanvasTool) -> some View {
        let isSelected = selectedTool == tool
        return Image(systemName: tool.icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.65))
            .frame(width: 44, height: 38)
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
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 40, height: 38)
            .contentShape(Rectangle())
    }

    private func staticButton(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 44, height: 38)
            .contentShape(Rectangle())
    }

    private var micButton: some View {
        Image(systemName: "mic")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 44, height: 38)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: -7, y: 5)
            }
            .contentShape(Rectangle())
    }

    private var verticalDivider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Self.dividerColor)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 8)
    }
}
