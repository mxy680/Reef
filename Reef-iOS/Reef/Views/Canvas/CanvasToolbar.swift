//
//  CanvasToolbar.swift
//  Reef
//
//  Floating toolbar — back button, tool island, undo/redo
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    let onClose: () -> Void

    /// Teal accent for selected state
    private static let teal = ReefColors.primary

    /// Pill behind the selected tool
    private static let selectedPill = ReefColors.primary.opacity(0.12)

    var body: some View {
        HStack {
            // Back button — separate island (top-left)
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ReefColors.gray600)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .canvasCard()
            .accessibilityLabel("Back")

            Spacer()

            // Drawing tools — center island
            HStack(spacing: 2) {
                ForEach(CanvasTool.allCases, id: \.self) { tool in
                    toolButton(tool)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .canvasCard()

            Spacer()

            // Undo/Redo — separate island (top-right)
            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ReefColors.gray400)
                        .frame(width: 44, height: 44)
                }
                Button(action: {}) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ReefColors.gray400)
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
            .canvasCard()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Tool Button

    private func toolButton(_ tool: CanvasTool) -> some View {
        let isSelected = selectedTool == tool
        return Image(systemName: tool.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(isSelected ? Self.teal : ReefColors.gray500)
            .frame(width: 40, height: 40)
            .background(isSelected ? Self.selectedPill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { selectedTool = tool }
    }
}

// MARK: - Canvas Card (shadow within layout bounds)

/// Like DashboardCardModifier but uses a ZStack instead of .background().offset().
/// The canvas toolbar overlays a UIKit PDFView (UIViewRepresentable) which renders
/// at a layer that covers SwiftUI backgrounds. A ZStack sibling approach keeps the
/// shadow above the PDFView layer.
private struct CanvasCardModifier: ViewModifier {
    private let cr: CGFloat = 16
    private let offset: CGFloat = 3

    func body(content: Content) -> some View {
        // ZStack approach: shadow is a sibling, not a background,
        // so it renders above the UIKit PDFView layer.
        ZStack(alignment: .topLeading) {
            // Shadow layer
            RoundedRectangle(cornerRadius: cr)
                .fill(ReefColors.gray500)
                .padding(.leading, offset)
                .padding(.top, offset)

            // Card layer
            content
                .background(ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: cr))
                .overlay(
                    RoundedRectangle(cornerRadius: cr)
                        .stroke(ReefColors.gray500, lineWidth: 1.5)
                )
                .padding(.trailing, offset)
                .padding(.bottom, offset)
        }
    }
}

private extension View {
    func canvasCard() -> some View {
        modifier(CanvasCardModifier())
    }
}
