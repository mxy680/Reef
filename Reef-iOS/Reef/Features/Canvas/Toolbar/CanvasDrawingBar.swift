import SwiftUI

// MARK: - Canvas Drawing Bar (Row 2)

struct CanvasDrawingBar: View {
    @Bindable var viewModel: CanvasViewModel

    /// The single toolbar teal.
    static let barColor = Color(hex: 0x4E8A97)
    private static let darkBarColor = ReefColors.CanvasDark.toolbar

    private var activeBarColor: Color {
        viewModel.isDarkMode ? Self.darkBarColor : Self.barColor
    }

    var body: some View {
        HStack(spacing: 0) {
            leftSection

            Spacer(minLength: 0)
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
        .background(activeBarColor)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    viewModel.toolbarRowMinX = geo.frame(in: .global).minX
                    viewModel.toolbarRowWidth = geo.size.width
                }
                .onChange(of: geo.size) { _, _ in
                    viewModel.toolbarRowMinX = geo.frame(in: .global).minX
                    viewModel.toolbarRowWidth = geo.size.width
                }
            }
        )
        // Popovers hang below Row 2
        .overlay(alignment: .bottomLeading) {
            if viewModel.showToolSettings {
                popoverAnchor {
                    toolSettingsPopover
                }
                .popoverPosition(
                    triggerMidX: viewModel.selectedToolMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 190
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showToolSettings)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showEraserSettings {
                popoverAnchor {
                    eraserSettingsPopover
                }
                .popoverPosition(
                    triggerMidX: viewModel.selectedToolMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 190
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showEraserSettings)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showPageSettings {
                popoverAnchor {
                    pageSettingsPopover
                }
                .popoverPosition(
                    triggerMidX: viewModel.pageSettingsMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 280
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showPageSettings)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showPageMenu {
                popoverAnchor {
                    pageMenuPopover
                }
                .popoverPosition(
                    triggerMidX: viewModel.pageMenuMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 230
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showPageMenu)
        // Tutor popovers
        .overlay(alignment: .bottomLeading) {
            if viewModel.showHintPopover, let step = viewModel.currentTutorStep {
                popoverAnchor {
                    tutorPopoverContent(title: "Hint", text: step.hint)
                }
                .popoverPosition(
                    triggerMidX: viewModel.hintMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 320
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showHintPopover)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showRevealPopover, let step = viewModel.currentTutorStep {
                popoverAnchor {
                    tutorPopoverContent(title: "Answer", text: step.answer)
                }
                .popoverPosition(
                    triggerMidX: viewModel.revealMidX,
                    rowMinX: viewModel.toolbarRowMinX,
                    rowWidth: viewModel.toolbarRowWidth,
                    popoverWidth: 320
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.showRevealPopover)
        .zIndex(1)
    }

    // MARK: - Popover Anchor

    private func popoverAnchor<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Color.clear.frame(height: 0)
            .overlay(alignment: .topLeading) {
                content()
            }
    }

    // MARK: - Left Section (Undo / Redo)

    private var leftSection: some View {
        HStack(spacing: 0) {
            CanvasToolbarButton(icon: "arrow.uturn.backward", isSelected: false, action: {
                viewModel.dismissAllPopovers()
            })
            CanvasToolbarButton(icon: "arrow.uturn.forward", isSelected: false, action: {
                viewModel.dismissAllPopovers()
            })
        }
    }

    // MARK: - Center Section (Drawing Tools)

    private var centerSection: some View {
        HStack(spacing: 0) {
            ForEach(CanvasToolType.allCases, id: \.self) { tool in
                CanvasToolbarButton(
                    icon: tool.icon,
                    isSelected: viewModel.selectedTool == tool,
                    isCustomIcon: tool.isCustomIcon,
                    action: {
                        viewModel.dismissAllPopovers()
                        if viewModel.selectedTool != tool {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedTool = tool
                            }
                        }
                        if tool.hasSettings {
                            viewModel.toolRetapped(tool)
                        }
                    }
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: viewModel.selectedTool) { _, newTool in
                                if newTool == tool {
                                    viewModel.selectedToolMidX = geo.frame(in: .global).midX
                                }
                            }
                            .onAppear {
                                if viewModel.selectedTool == tool {
                                    viewModel.selectedToolMidX = geo.frame(in: .global).midX
                                }
                            }
                    }
                )
            }
        }
    }

    // MARK: - Canvas Utilities (Ruler, Background, Pages)

    private var canvasUtilitiesSection: some View {
        HStack(spacing: 0) {
            CanvasToolbarButton(
                icon: "pencil.and.ruler.fill",
                isSelected: viewModel.showRuler,
                action: {
                    viewModel.dismissAllPopovers()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showRuler.toggle()
                    }
                }
            )
            CanvasToolbarButton(
                icon: "square.grid.3x3",
                isSelected: viewModel.hasActiveOverlay,
                action: {
                    viewModel.dismissAllPopovers()
                    viewModel.showPageSettings = true
                }
            )
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewModel.pageSettingsMidX = geo.frame(in: .global).midX }
                        .onChange(of: viewModel.showPageSettings) { _, _ in
                            viewModel.pageSettingsMidX = geo.frame(in: .global).midX
                        }
                }
            )

            CanvasToolbarButton(
                icon: "doc.badge.plus",
                isSelected: viewModel.showPageMenu,
                action: {
                    viewModel.dismissAllPopovers()
                    viewModel.showPageMenu = true
                }
            )
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewModel.pageMenuMidX = geo.frame(in: .global).midX }
                        .onChange(of: viewModel.showPageMenu) { _, _ in
                            viewModel.pageMenuMidX = geo.frame(in: .global).midX
                        }
                }
            )
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        HStack(spacing: 0) {
            if viewModel.tutorModeOn, viewModel.currentTutorStep != nil {
                stepButton(icon: "lightbulb.fill", isActive: viewModel.showHintPopover) {
                    viewModel.dismissAllPopovers()
                    viewModel.showHintPopover = true
                }
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { viewModel.hintMidX = geo.frame(in: .global).midX }
                        .onChange(of: geo.frame(in: .global).midX) { _, v in viewModel.hintMidX = v }
                })

                stepButton(icon: "eye.fill", isActive: viewModel.showRevealPopover) {
                    viewModel.dismissAllPopovers()
                    viewModel.showRevealPopover = true
                }
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { viewModel.revealMidX = geo.frame(in: .global).midX }
                        .onChange(of: geo.frame(in: .global).midX) { _, v in viewModel.revealMidX = v }
                })

                makeDivider()
            }

            // Mic placeholder
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 36, height: 36)
        }
    }

    // MARK: - Right Section

    private var rightSection: some View {
        HStack(spacing: 0) {
            CanvasToolbarButton(icon: "sidebar.trailing", isSelected: false, action: {
                viewModel.dismissAllPopovers()
            })
            CanvasToolbarButton(icon: "square.and.arrow.up.fill", isSelected: false, action: {
                viewModel.dismissAllPopovers()
            })
            CanvasToolbarButton(
                icon: viewModel.isDarkMode ? "sun.max.fill" : "moon.fill",
                isSelected: viewModel.isDarkMode,
                action: {
                    viewModel.dismissAllPopovers()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.isDarkMode.toggle()
                    }
                }
            )
        }
    }

    // MARK: - Divider

    private func makeDivider() -> some View {
        Text("|")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.5))
            .frame(width: 20)
    }

    // MARK: - Step Button

    private func stepButton(
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.9))
                .frame(width: 32, height: 32, alignment: .center)
                .background(isActive ? Color.white.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .frame(width: 32, height: 32)
        .buttonStyle(.plain)
    }

    // MARK: - Inline Popovers

    private var toolSettingsPopover: some View {
        let arrowOffset = popoverArrowOffset(
            triggerMidX: viewModel.selectedToolMidX,
            rowMinX: viewModel.toolbarRowMinX,
            rowWidth: viewModel.toolbarRowWidth,
            popoverWidth: 190
        )
        return PopoverCard(arrowOffset: arrowOffset, maxWidth: 190) {
            CanvasToolSettingsContent(viewModel: viewModel)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
    }

    private var eraserSettingsPopover: some View {
        let arrowOffset = popoverArrowOffset(
            triggerMidX: viewModel.selectedToolMidX,
            rowMinX: viewModel.toolbarRowMinX,
            rowWidth: viewModel.toolbarRowWidth,
            popoverWidth: 190
        )
        return PopoverCard(arrowOffset: arrowOffset, maxWidth: 190) {
            CanvasEraserSettingsContent(viewModel: viewModel)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
    }

    private var pageSettingsPopover: some View {
        let arrowOffset = popoverArrowOffset(
            triggerMidX: viewModel.pageSettingsMidX,
            rowMinX: viewModel.toolbarRowMinX,
            rowWidth: viewModel.toolbarRowWidth,
            popoverWidth: 280
        )
        return PopoverCard(arrowOffset: arrowOffset, maxWidth: 280) {
            CanvasPageSettingsContent(viewModel: viewModel)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
    }

    private var pageMenuPopover: some View {
        let arrowOffset = popoverArrowOffset(
            triggerMidX: viewModel.pageMenuMidX,
            rowMinX: viewModel.toolbarRowMinX,
            rowWidth: viewModel.toolbarRowWidth,
            popoverWidth: 230
        )
        return PopoverCard(arrowOffset: arrowOffset, maxWidth: 230) {
            CanvasPageMenuContent(viewModel: viewModel)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
    }

    private func tutorPopoverContent(title: String, text: String) -> some View {
        let arrowOffset = popoverArrowOffset(
            triggerMidX: title == "Hint" ? viewModel.hintMidX : viewModel.revealMidX,
            rowMinX: viewModel.toolbarRowMinX,
            rowWidth: viewModel.toolbarRowWidth,
            popoverWidth: 320
        )
        return PopoverCard(arrowOffset: arrowOffset, maxWidth: 320) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ReefColors.black)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(text)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundColor(ReefColors.gray600)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .transition(.scale(scale: 0.01, anchor: .top))
    }

    // MARK: - Popover Positioning

    private func popoverArrowOffset(
        triggerMidX: CGFloat,
        rowMinX: CGFloat,
        rowWidth: CGFloat,
        popoverWidth: CGFloat
    ) -> CGFloat {
        let idealX = triggerMidX - rowMinX - popoverWidth / 2
        let clampedX = max(12, min(idealX, rowWidth - popoverWidth - 12))
        return (triggerMidX - rowMinX) - (clampedX + popoverWidth / 2)
    }
}

// MARK: - Popover Position Modifier

private struct PopoverPositionModifier: ViewModifier {
    let triggerMidX: CGFloat
    let rowMinX: CGFloat
    let rowWidth: CGFloat
    let popoverWidth: CGFloat

    func body(content: Content) -> some View {
        let idealX = triggerMidX - rowMinX - popoverWidth / 2
        let clampedX = max(12, min(idealX, rowWidth - popoverWidth - 12))
        content.offset(x: clampedX)
    }
}

extension View {
    fileprivate func popoverPosition(
        triggerMidX: CGFloat,
        rowMinX: CGFloat,
        rowWidth: CGFloat,
        popoverWidth: CGFloat
    ) -> some View {
        modifier(PopoverPositionModifier(
            triggerMidX: triggerMidX,
            rowMinX: rowMinX,
            rowWidth: rowWidth,
            popoverWidth: popoverWidth
        ))
    }
}
