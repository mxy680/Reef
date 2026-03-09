//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen scrollable PDF viewer with PencilKit drawing
//

import SwiftUI
import UIKit
import PencilKit

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var viewModel = CanvasViewModel()
    @State private var selectedTool: CanvasTool = .pen
    @State private var currentQuestionIndex = 0
    @State private var tutorModeOn = false
    @State private var currentPageIndex = 0
    @State private var pageVersion = UUID()
    @State private var showPageMenu = false
    @State private var showRuler = false
    @State private var drawingManager: DrawingManager?
    @State private var penColor: UIColor = .black
    @State private var penWidth: CGFloat = 3.5
    @State private var showToolSettings = false
    @State private var selectedToolMidX: CGFloat = 0
    @State private var customColors: [UIColor] = []
    @State private var showColorPicker = false
    @State private var showPageSettings = false
    @State private var pageOverlaySettings = PageOverlaySettings()
    @State private var answerKeys: [Int: QuestionAnswer] = [:]

    private var isReconstructed: Bool {
        document.questionPages != nil
    }

    /// Current PencilKit tool derived from toolbar selection + settings
    private var currentPKTool: PKTool {
        selectedTool.pkTool(color: penColor, width: penWidth)
    }

    private static let cream = Color(hex: 0xF8F0E6)

    /// Tab strip = barColor (0x4E8A97) darkened 18% for safe area.
    /// RGB: (78,138,151) * 0.82 ≈ (64,113,124)
    private static let safeAreaColor = Color(red: 64/255.0, green: 113/255.0, blue: 124/255.0)

    private var canvasBackground: Color {
        theme.isDarkMode ? ReefColors.CanvasDark.background : Self.cream
    }

    private var canvasSafeArea: Color {
        theme.isDarkMode ? ReefColors.CanvasDark.safeArea : Self.safeAreaColor
    }

    var body: some View {
        ZStack {
            // Full-bleed tab strip teal so the safe area is never black
            canvasSafeArea.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(canvasBackground)
                        .transition(.opacity)
                } else if let error = viewModel.error {
                    errorView(error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(canvasBackground)
                        .transition(.opacity)
                } else if let pdf = viewModel.pdfDocument, let manager = drawingManager {
                    CanvasToolbar(
                        selectedTool: $selectedTool,
                        currentQuestionIndex: $currentQuestionIndex,
                        questionCount: isReconstructed
                            ? (document.problemCount ?? 1)
                            : 1,
                        onClose: {
                            manager.saveAll()
                            Task { await viewModel.saveIfNeeded() }
                            onDismiss()
                        },
                        tutorModeOn: $tutorModeOn,
                        isReconstructed: isReconstructed,
                        documentName: document.displayName,
                        onPageAction: { handlePageAction($0) },
                        showPageMenu: $showPageMenu,
                        showRuler: $showRuler,
                        onUndo: { manager.undo() },
                        onRedo: { manager.redo() },
                        onToolRetapped: { _ in
                            showToolSettings = true
                        },
                        selectedToolMidX: $selectedToolMidX,
                        showPageSettings: $showPageSettings,
                        hasActiveOverlay: pageOverlaySettings.type != .none,
                        pageOverlaySettings: $pageOverlaySettings
                    )
                    .zIndex(1)
                    .overlay(alignment: .bottomLeading) {
                        if showToolSettings {
                            GeometryReader { geo in
                                let containerMinX = geo.frame(in: .global).minX
                                let containerWidth = geo.size.width
                                let popoverWidth: CGFloat = 190
                                let idealX = selectedToolMidX - containerMinX - popoverWidth / 2
                                let clampedX = max(12, min(idealX, containerWidth - popoverWidth - 12))
                                let arrowOffset = (selectedToolMidX - containerMinX) - (clampedX + popoverWidth / 2)

                                PopoverCard(arrowOffset: arrowOffset) {
                                    ToolSettingsPopover(
                                        selectedColor: $penColor,
                                        lineWidth: $penWidth,
                                        customColors: $customColors,
                                        onAddColorTapped: { showColorPicker = true }
                                    )
                                }
                                .transition(.scale(scale: 0.01, anchor: .top))
                                .offset(x: clampedX)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showToolSettings)
                    .zIndex(2) // popover overlays step toolbar

                    if tutorModeOn && isReconstructed {
                        TutorStepToolbar(
                            questionIndex: currentQuestionIndex,
                            answerKey: answerKeys[currentQuestionIndex + 1]
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ZStack(alignment: .top) {
                        CanvasPageView(
                            pdfDocument: pdf,
                            pageRange: pageRange(for: currentQuestionIndex),
                            drawingManager: manager,
                            currentTool: currentPKTool,
                            onVisiblePageChanged: { currentPageIndex = $0 },
                            darkMode: theme.isDarkMode,
                            overlaySettings: pageOverlaySettings
                        )
                        .id("\(currentQuestionIndex)-\(pageVersion)")

                        if showRuler {
                            RulerOverlayView()
                                .transition(.opacity)
                        }

                    }
                    .background(canvasBackground)
                    .overlay {
                        // Tap-to-dismiss layer (covers canvas only, not toolbar)
                        if showToolSettings {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showToolSettings = false }
                        }
                        if showPageSettings {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showPageSettings = false }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.25), value: tutorModeOn)
            .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: theme.isDarkMode)
            .animation(.easeInOut(duration: 0.2), value: showRuler)

            // Centered color picker popup
            if showColorPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showColorPicker = false }

                AddColorPopup(
                    onAdd: { color in
                        customColors.append(color)
                        penColor = color
                        showColorPicker = false
                    },
                    onDismiss: { showColorPicker = false }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: showColorPicker)
        .animation(.spring(duration: 0.2), value: showPageSettings)
        .ignoresSafeArea()
        .overlayPreferenceValue(PageMenuAnchorKey.self) { anchor in
            if showPageMenu, let anchor {
                GeometryReader { proxy in
                    let rect = proxy[anchor]
                    let menuWidth: CGFloat = 230
                    // Center menu horizontally under the button, clamped to screen
                    let menuX = max(8, min(
                        rect.midX - menuWidth / 2,
                        proxy.size.width - menuWidth - 12
                    ))

                    // Dismiss backdrop
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2, bounce: 0.15)) {
                                showPageMenu = false
                            }
                        }

                    // Custom popover centered below button
                    PageMenuView(onAction: { action in
                        withAnimation(.spring(duration: 0.2, bounce: 0.15)) {
                            showPageMenu = false
                        }
                        handlePageAction(action)
                    }, canUndo: viewModel.canUndo)
                    .transition(
                        .scale(scale: 0.92, anchor: .top)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -4))
                    )
                    .offset(x: menuX, y: rect.maxY + 10)
                }
                .ignoresSafeArea()
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.15), value: showPageMenu)
        .task {
            #if DEBUG
            if document.id == "dev-test" {
                viewModel.loadTestDocument()
                let manager = DrawingManager(documentId: "dev-test")
                manager.loadAll(pageCount: 1)
                drawingManager = manager
                return
            }
            #endif
            await viewModel.loadDocument(document)
            if let pdf = viewModel.pdfDocument {
                let manager = DrawingManager(documentId: document.id)
                manager.loadAll(pageCount: pdf.pageCount)
                drawingManager = manager
            }
            if isReconstructed {
                answerKeys = await AnswerKeyService.shared.fetchAnswerKeys(documentId: document.id)
            }
        }
        .onChange(of: selectedTool) { _, newTool in
            if !newTool.hasSettings {
                showToolSettings = false
            }
        }
        .onChange(of: currentQuestionIndex) { _, _ in
            drawingManager?.saveAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            drawingManager?.saveAll()
        }
        .onDisappear {
            Task { await viewModel.saveIfNeeded() }
        }
    }

    // MARK: - Page Actions

    private func handlePageAction(_ action: PageAction) {
        switch action {
        case .addBlankAtEnd:
            viewModel.addBlankPage(at: viewModel.pageCount)
        case .addBlankAfterCurrent:
            viewModel.addBlankPage(at: currentPageIndex + 1)
        case .deleteCurrentPage:
            viewModel.deletePageAt(currentPageIndex)
            if currentPageIndex >= viewModel.pageCount {
                currentPageIndex = max(0, viewModel.pageCount - 1)
            }
        case .deleteAllPages:
            viewModel.deleteAllPages()
            currentPageIndex = 0
        case .undo:
            if viewModel.undo() {
                currentPageIndex = min(currentPageIndex, max(0, viewModel.pageCount - 1))
            }
        }
        pageVersion = UUID()
    }

    // MARK: - Page Range

    private func pageRange(for questionIndex: Int) -> ClosedRange<Int>? {
        guard let pages = document.questionPages,
              questionIndex < pages.count,
              pages[questionIndex].count == 2 else { return nil }
        return pages[questionIndex][0]...pages[questionIndex][1]
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Document skeleton placeholder
            VStack(spacing: 0) {
                // Page shape with ruled lines + shimmer
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    // Ruled lines
                    GeometryReader { geo in
                        let lineCount = 14
                        let topInset = geo.size.height * 0.12
                        let spacing = (geo.size.height * 0.72) / CGFloat(lineCount)
                        let hPad = geo.size.width * 0.12

                        ForEach(0..<lineCount, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(ReefColors.gray100)
                                .frame(
                                    width: i == 0
                                        ? (geo.size.width - hPad * 2) * 0.6
                                        : (geo.size.width - hPad * 2) * CGFloat([1.0, 0.92, 0.85, 1.0, 0.78, 0.95, 1.0, 0.88, 0.7, 1.0, 0.93, 0.82, 0.96, 0.6][i % 14]),
                                    height: 4
                                )
                                .offset(x: hPad, y: topInset + CGFloat(i) * spacing)
                        }
                    }

                    ShimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 200, height: 260)
            }

            Spacer().frame(height: 28)

            // Document name
            Text(document.displayName)
                .font(.epilogue(16, weight: .semiBold))
                .tracking(-0.04 * 16)
                .foregroundStyle(ReefColors.black)
                .lineLimit(1)

            Spacer().frame(height: 10)

            // Subtle loading indicator
            HStack(spacing: 8) {
                ProgressView()
                    .tint(ReefColors.primary)
                    .scaleEffect(0.8)

                Text("Opening...")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(ReefColors.gray500)
            }

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(ReefColors.gray400)

            Text(message)
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(ReefColors.gray600)

            Text("Go Back")
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(ReefColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { onDismiss() }
        }
    }
}
