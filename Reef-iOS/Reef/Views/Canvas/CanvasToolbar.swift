//
//  CanvasToolbar.swift
//  Reef
//
//  GoodNotes 6-style two-row toolbar — problem tabs + drawing tools (UI only)
//

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    let questionCount: Int
    let onClose: () -> Void

    @State private var currentQuestionIndex = 0
    @State private var tutorModeOn = false

    /// The single toolbar teal — everything derives from this via white/black opacity.
    static let barColor = Color(hex: 0x4E8A97)

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Problem tab bar (darkened teal)
            problemTabBar

            // Row 2: Tool bar
            HStack(spacing: 0) {
                leftSection
                makeDivider()
                centerSection
                makeDivider()
                canvasUtilitiesSection
                makeDivider()
                aiSection
                Spacer(minLength: 0)
                rightSection
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Self.barColor)

            // Bottom separator
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .padding(.top, safeAreaTop)
        .background(
            // Tab strip = barColor darkened with black overlay, extends into safe area
            ZStack {
                Self.barColor
                Color.black.opacity(0.18)
            }
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Problem Tab Bar

    /// Tab strip background: barColor darkened by overlaying black.
    private var tabStripBg: some View {
        ZStack {
            Self.barColor
            Color.black.opacity(0.18)
        }
    }

    private var problemTabBar: some View {
        ZStack(alignment: .bottom) {
            // Recessed tab strip background (same teal, darkened)
            tabStripBg

            // Scrollable Chrome-style tabs
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<questionCount, id: \.self) { index in
                            let isSelected = index == currentQuestionIndex

                            Button {
                                currentQuestionIndex = index
                            } label: {
                                Text("Q\(index + 1)")
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(
                                        isSelected ? .white : Color.white.opacity(0.6)
                                    )
                                    .frame(minWidth: 44, minHeight: 30)
                                    .padding(.horizontal, 6)
                                    .background(isSelected ? Self.barColor : Color.clear)
                                    .clipShape(ChromeTabShape())
                                    .overlay(
                                        isSelected
                                            ? ChromeTabShape()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                            : nil
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(index)

                            // Separator between unselected tabs
                            if index < questionCount - 1
                                && !isSelected
                                && index + 1 != currentQuestionIndex
                            {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 1, height: 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
                }
                .padding(.leading, 48)
                .padding(.trailing, 150)
                .onChange(of: currentQuestionIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            // Pinned edges: Home + Tutor Mode
            HStack(spacing: 0) {
                // Home button
                HStack(spacing: 0) {
                    Button {
                        print("🏠 HOME BUTTON TAPPED")
                        onClose()
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
                .background(tabStripBg)

                Spacer()

                // Tutor Mode toggle
                HStack(spacing: 6) {
                    Text("Tutor Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("", isOn: $tutorModeOn)
                        .toggleStyle(TutorToggleStyle())
                        .labelsHidden()
                }
                .padding(.trailing, 10)
                .padding(.leading, 4)
                .frame(height: 40)
                .background(tabStripBg)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    // MARK: - Left Section (Undo / Redo)

    private var leftSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "arrow.uturn.backward", isSelected: false, action: {})
            ToolbarButton(icon: "arrow.uturn.forward", isSelected: false, action: {})
        }
    }

    // MARK: - Center Section (Drawing Tools)

    private var centerSection: some View {
        HStack(spacing: 0) {
            ForEach(CanvasTool.allCases, id: \.self) { tool in
                ToolbarButton(
                    icon: tool.icon,
                    isSelected: selectedTool == tool,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTool = tool
                        }
                    }
                )
            }
        }
    }

    // MARK: - Canvas Utilities (Ruler, Background, Pages)

    private var canvasUtilitiesSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "pencil.and.ruler.fill", isSelected: false, action: {})
            ToolbarButton(icon: "document.badge.gearshape.fill", isSelected: false, action: {})
            ToolbarButton(icon: "doc.fill.badge.plus", isSelected: false, action: {})
        }
    }

    // MARK: - AI Section (Mic + More)

    private var aiSection: some View {
        HStack(spacing: 0) {
            // Mic with status indicator
            ZStack(alignment: .topTrailing) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .offset(x: -2, y: 2)
            }
            .frame(width: 36, height: 36)

            ToolbarButton(icon: "ellipsis.circle.fill", isSelected: false, action: {})
        }
    }

    // MARK: - Right Section (Sidebar, Export, Dark Mode)

    private var rightSection: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "sidebar.trailing", isSelected: false, action: {})
            ToolbarButton(icon: "square.and.arrow.up.fill", isSelected: false, action: {})
            ToolbarButton(icon: "moon.fill", isSelected: false, action: {})
        }
    }

    // MARK: - Divider

    private func makeDivider() -> some View {
        Text("|")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.5))
            .frame(width: 20)
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    isSelected
                        ? Color.white.opacity(0.25)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }
}

// MARK: - Chrome Tab Shape

private struct ChromeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let curve: CGFloat = 8
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + curve, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - curve, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Tutor Toggle Style

/// Custom toggle using only white/black opacity on the teal toolbar background.
private struct TutorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let trackWidth: CGFloat = 36
        let trackHeight: CGFloat = 20
        let knobSize: CGFloat = 16
        let knobPadding: CGFloat = 2

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn
                          ? Color.white.opacity(0.35)
                          : Color.black.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color.white.opacity(0.25),
                                lineWidth: 0.5
                            )
                    )
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
        }
        .buttonStyle(.plain)
    }
}
