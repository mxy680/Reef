import SwiftUI
import PencilKit

// MARK: - Canvas Drawing Bar (Row 2)

struct CanvasDrawingBar: View {
    @Bindable var viewModel: CanvasViewModel
    var drawingManager: CanvasDrawingManager
    var onScrollToPage: ((Int) -> Void)?

    /// The single toolbar teal.
    static let barColor = Color(hex: 0x4E8A97)
    private static let darkBarColor = ReefColors.CanvasDark.toolbar

    private var activeBarColor: Color {
        viewModel.isDarkMode ? Self.darkBarColor : Self.barColor
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left-side: undo / redo
            HStack(alignment: .center, spacing: 0) {
                Button {
                    drawingManager.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(drawingManager.canUndo ? 0.8 : 0.3))
                        .frame(width: 38, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!drawingManager.canUndo)

                Button {
                    drawingManager.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(drawingManager.canRedo ? 0.8 : 0.3))
                        .frame(width: 38, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!drawingManager.canRedo)
            }
            .padding(.leading, 4)

            divider

            // Drawing tools
            HStack(alignment: .center, spacing: 0) {
                drawingToolButton(.pen)
                drawingToolButton(.highlighter)
                drawingToolButton(.eraser)
                drawingToolButton(.shapes)
                drawingToolButton(.lasso)
                drawingToolButton(.handDraw)
            }

            divider

            // Canvas tools: ruler, calculator, add page, page settings
            HStack(alignment: .center, spacing: 0) {
                toolbarButton(icon: "canvas.ruler_new", active: viewModel.showRuler) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showRuler.toggle()
                    }
                }

                toolbarButton(icon: "canvas.calculator", active: viewModel.showCalculator) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showCalculator.toggle()
                    }
                }

                toolbarButton(icon: "canvas.add_blank_page", active: viewModel.showPageControls) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showPageControls.toggle()
                        if viewModel.showPageControls { viewModel.showPageSettings = false }
                    }
                }

                toolbarButton(icon: "canvas.page_settings_new", active: viewModel.showPageSettings) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showPageSettings.toggle()
                        if viewModel.showPageSettings { viewModel.showPageControls = false }
                    }
                }
            }

            Spacer()

            // Tool settings — shown when pen, highlighter, eraser is selected, or page controls active
            if viewModel.showPageControls {
                pageControlsSection
            } else if viewModel.showPageSettings {
                pageSettingsSection
            } else if viewModel.selectedTool == .pen || viewModel.selectedTool == .highlighter || viewModel.selectedTool == .shapes {
                penSettingsSection
            } else if viewModel.selectedTool == .eraser {
                eraserSettingsSection
            }

            Spacer()

            // Right-side controls
            HStack(alignment: .center, spacing: 0) {
                // Mic toggle
                toolbarButton(
                    icon: viewModel.isMicOn ? "canvas.mic_on" : "canvas.mic_off",
                    active: viewModel.isMicOn
                ) {
                    viewModel.toggleMic()
                }

                // Tutor: prev/next question + reset
                if viewModel.tutorModeOn {
                    divider

                    Button {
                        viewModel.goToPreviousQuestion()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(viewModel.canGoToPreviousQuestion ? 0.8 : 0.3))
                            .frame(width: 38, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canGoToPreviousQuestion)

                    Button {
                        _ = viewModel.skipToNextQuestion()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(viewModel.canSkipToNextQuestion ? 0.8 : 0.3))
                            .frame(width: 38, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSkipToNextQuestion)

                    Button {
                        viewModel.showResetQuestionConfirmation = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 38, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                divider

                // Dark mode toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.isDarkMode.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 38, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.showBugReport = true
                } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 38, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                toolbarButton(icon: "canvas.export", yOffset: -1) {
                    viewModel.exportDocument()
                }
                .opacity(viewModel.isExporting ? 0.3 : 1.0)
                .disabled(viewModel.isExporting)

                toolbarButton(
                    icon: viewModel.showSidebar ? "canvas.sidebar_close" : "canvas.sidebar_open",
                    active: viewModel.showSidebar
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.showSidebar.toggle()
                    }
                }
                .opacity(viewModel.tutorModeOn ? 1.0 : 0.3)
                .disabled(!viewModel.tutorModeOn)
            }
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(activeBarColor)
    }

    // MARK: - Pen/Highlighter Settings

    private let defaultPenColors: [UIColor] = [
        .black,
        UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1), // red
        UIColor(red: 0.20, green: 0.50, blue: 0.85, alpha: 1), // blue
    ]

    private let defaultHighlighterColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1),   // yellow
        UIColor(red: 1.0, green: 0.55, blue: 0.65, alpha: 1),   // pink
        UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),     // gray
    ]

    private var activeColor: Binding<UIColor> {
        switch viewModel.selectedTool {
        case .highlighter:
            Binding(get: { viewModel.highlighterColor }, set: { viewModel.highlighterColor = $0 })
        case .shapes:
            Binding(get: { viewModel.shapesColor }, set: { viewModel.shapesColor = $0 })
        default:
            Binding(get: { viewModel.penColor }, set: { viewModel.penColor = $0 })
        }
    }

    private var activeWidth: Binding<CGFloat> {
        switch viewModel.selectedTool {
        case .highlighter:
            Binding(get: { viewModel.highlighterWidth }, set: { viewModel.highlighterWidth = $0 })
        case .shapes:
            Binding(get: { viewModel.shapesWidth }, set: { viewModel.shapesWidth = $0 })
        default:
            Binding(get: { viewModel.penWidth }, set: { viewModel.penWidth = $0 })
        }
    }

    private var allColors: [UIColor] {
        switch viewModel.selectedTool {
        case .highlighter:
            return defaultHighlighterColors + viewModel.customHighlighterColors
        case .shapes:
            return defaultPenColors + viewModel.customShapesColors
        default:
            return defaultPenColors + viewModel.customColors
        }
    }

    private var penSettingsSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Color swatches
            HStack(spacing: 6) {
                ForEach(Array(allColors.enumerated()), id: \.offset) { _, color in
                    colorSwatch(color)
                }

                // Add color button (up to 6 total)
                if allColors.count < 6 {
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showAddColor = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                )
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .offset(x: 1.5, y: 1.5)
                                )

                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Thickness slider
            HStack(spacing: 6) {
                Reef3DSlider(value: activeWidth, range: 0.5...8.0)

                // Preview dot — scales with current width
                let dotSize = 4 + (activeWidth.wrappedValue - 0.5) / 7.5 * 14
                Circle()
                    .fill(Color(activeColor.wrappedValue))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: 1, y: 1)
                    )
                    .frame(width: 20, height: 20)
                    .animation(.easeOut(duration: 0.1), value: activeWidth.wrappedValue)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Eraser Settings

    private var eraserSettingsSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Mode toggle: stroke vs area
            HStack(spacing: 2) {
                eraserModeButton(
                    assetIcon: "canvas.eraser_area",
                    isSelected: viewModel.eraserMode == .vector
                ) {
                    viewModel.eraserMode = .vector
                }

                eraserModeButton(
                    assetIcon: "canvas.eraser_stroke",
                    isSelected: viewModel.eraserMode == .bitmap
                ) {
                    viewModel.eraserMode = .bitmap
                }
            }

            // Thickness slider
            HStack(spacing: 6) {
                Reef3DSlider(value: $viewModel.eraserWidth, range: 2.0...40.0)

                // Preview dot
                let dotSize = 6 + (viewModel.eraserWidth - 2) / 38 * 14
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: 1, y: 1)
                    )
                    .frame(width: 22, height: 22)
                    .animation(.easeOut(duration: 0.1), value: viewModel.eraserWidth)
            }

            divider

            // Clear all strokes — same style as Delete Page pill
            clearAllPill
        }
        .transition(.opacity)
    }

    // MARK: - Page Controls Section

    private var pageControlsSection: some View {
        HStack(alignment: .center, spacing: 8) {
            // Page X of Y with prev/next navigation
            HStack(spacing: 4) {
                Button {
                    let newIndex = viewModel.currentPageIndex - 1
                    viewModel.currentPageIndex = newIndex
                    onScrollToPage?(newIndex)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(viewModel.currentPageIndex > 0 ? 0.8 : 0.3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentPageIndex <= 0)

                Text("Page \(viewModel.currentPageIndex + 1) of \(viewModel.pageCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize()

                Button {
                    let newIndex = viewModel.currentPageIndex + 1
                    viewModel.currentPageIndex = newIndex
                    onScrollToPage?(newIndex)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(viewModel.currentPageIndex < viewModel.pageCount - 1 ? 0.8 : 0.3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentPageIndex >= viewModel.pageCount - 1)
            }

            divider

            // Add page actions
            HStack(spacing: 4) {
                SettingsPill(
                    label: "Add After",
                    isSelected: false,
                    horizontalPadding: 10
                ) {
                    viewModel.addBlankPageAfterCurrent(drawingManager: drawingManager)
                }
                .scaleEffect(0.85)

                SettingsPill(
                    label: "Add to End",
                    isSelected: false,
                    horizontalPadding: 10
                ) {
                    viewModel.addBlankPageAtEnd(drawingManager: drawingManager)
                }
                .scaleEffect(0.85)
            }

            divider

            // Delete page — red tinted label via overlay
            deletePagePill
        }
        .transition(.opacity)
    }

    private var deletePagePill: some View {
        let canDelete = viewModel.pageCount > 1
        return Button {
            viewModel.deleteCurrentPage(drawingManager: drawingManager)
        } label: {
            Text("Delete Page")
                .font(.epilogue(12, weight: .bold))
                .tracking(-0.04 * 12)
                .foregroundColor(Color(red: 0.85, green: 0.20, blue: 0.20))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(red: 0.85, green: 0.20, blue: 0.20), lineWidth: 1.5)
                )
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .offset(x: 3, y: 3)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(0.85)
        .opacity(canDelete ? 1 : 0.4)
        .disabled(!canDelete)
    }

    private var clearAllPill: some View {
        Button {
            viewModel.showClearConfirmation = true
        } label: {
            Text("Clear All")
                .font(.epilogue(12, weight: .bold))
                .tracking(-0.04 * 12)
                .foregroundColor(Color(red: 0.85, green: 0.20, blue: 0.20))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(red: 0.85, green: 0.20, blue: 0.20), lineWidth: 1.5)
                )
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .offset(x: 3, y: 3)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(0.85)
    }

    // MARK: - Page Settings Section

    private var pageSettingsSection: some View {
        HStack(alignment: .center, spacing: 6) {
            // Overlay type icons
            HStack(spacing: 0) {
                overlayTypeButton(type: .none, icon: "xmark", systemIcon: true)
                overlayTypeButton(type: .grid, icon: "grid", systemIcon: true)
                overlayTypeButton(type: .dots, icon: "circle.grid.3x3.fill", systemIcon: true)
                overlayTypeButton(type: .lines, icon: "line.3.horizontal", systemIcon: true)
            }

            divider

            // Opacity slider
            HStack(spacing: 3) {
                Image(systemName: "sun.min")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))

                Reef3DSlider(
                    value: $viewModel.overlaySettings.opacity,
                    range: 0.1...1.0,
                    width: 55,
                    height: 24,
                    trackHeight: 6,
                    thumbSize: 12
                )

                Text("\(Int(viewModel.overlaySettings.opacity * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 26, alignment: .leading)
            }

            divider

            // Spacing slider
            HStack(spacing: 3) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))

                Reef3DSlider(
                    value: $viewModel.overlaySettings.spacing,
                    range: 10.0...50.0,
                    width: 55,
                    height: 24,
                    trackHeight: 6,
                    thumbSize: 12
                )

                Text("\(Int(viewModel.overlaySettings.spacing))pt")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 30, alignment: .leading)
            }
        }
        .transition(.opacity)
    }

    private func overlayTypeButton(type: CanvasOverlayType, icon: String, systemIcon: Bool = false) -> some View {
        let isSelected = viewModel.overlaySettings.type == type
        return Button {
            viewModel.overlaySettings.type = type
        } label: {
            Group {
                if systemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                } else {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
            }
            .foregroundColor(.white.opacity(isSelected ? 1 : 0.4))
            .frame(width: 32, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ color: UIColor) -> some View {
        let isSelected = activeColor.wrappedValue == color
        return Button {
            activeColor.wrappedValue = color
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5)
                )
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .offset(x: 1.5, y: 1.5)
                )
                .overlay(
                    isSelected
                        ? Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 25, height: 25)
                        : nil
                )
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drawing Tool Button

    private func drawingToolButton(_ tool: CanvasToolType) -> some View {
        let isSelected = viewModel.selectedTool == tool
        return Button {
            viewModel.selectedTool = tool
            viewModel.showPageControls = false
            viewModel.showPageSettings = false
        } label: {
            Image(tool.icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundColor(.white.opacity(isSelected ? 1 : 0.5))
                .frame(width: 38, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Text("|")
            .font(.system(size: 18, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.3))
            .frame(width: 16)
    }

    // MARK: - Helpers

    private func toolbarButton(
        icon: String,
        active: Bool = false,
        yOffset: CGFloat = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .offset(y: yOffset)
                .foregroundColor(.white.opacity(active ? 1 : 0.8))
                .frame(width: 38, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func eraserModeButton(
        assetIcon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(assetIcon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
