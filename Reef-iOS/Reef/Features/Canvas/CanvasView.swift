import SwiftUI
import PencilKit
import Combine

// MARK: - Canvas View (fullscreen container)

struct CanvasView: View {
    @Bindable var viewModel: CanvasViewModel
    let onDismiss: () -> Void

    @State private var scrollToPageIndex: Int? = nil
    @State private var autoSaveTask: Task<Void, Never>?

    @Environment(\.reefLayoutMetrics) private var metrics

    var body: some View {
        ZStack {
            // Background
            (viewModel.isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar — always full width
                VStack(spacing: 0) {
                    CanvasInfoStrip(
                        viewModel: viewModel,
                        onClose: {
                            viewModel.saveCanvasState()
                            onDismiss()
                        }
                    )

                    CanvasDrawingBar(
                        viewModel: viewModel,
                        drawingManager: viewModel.drawingManager,
                        onScrollToPage: { index in
                            scrollToPageIndex = index
                        }
                    )

                    // Bottom separator
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 0.5)
                }
                .padding(.top, 12)
                .background(
                    ZStack {
                        (viewModel.isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasDrawingBar.barColor)
                        Color.black.opacity(viewModel.isDarkMode ? 0.3 : 0.18)
                    }
                    .ignoresSafeArea(edges: .top)
                )
                .zIndex(2)

                // Canvas + Sidebar — sidebar only pushes the canvas area
                HStack(spacing: 0) {
                    CanvasPageView(
                        pdfDocument: viewModel.pdfDocument,
                        drawingManager: viewModel.drawingManager,
                        currentTool: viewModel.activePKTool,
                        drawingPolicy: viewModel.activeDrawingPolicy,
                        selectedToolType: viewModel.selectedTool,
                        darkMode: viewModel.isDarkMode,
                        overlayType: viewModel.overlaySettings.type,
                        overlaySpacing: viewModel.overlaySettings.spacing,
                        overlayOpacity: viewModel.overlaySettings.opacity,
                        pageVersion: viewModel.pageVersion,
                        scrollToPageIndex: scrollToPageIndex,
                        onCanvasTouchBegan: {
                            viewModel.dismissAllPopovers()
                            scrollToPageIndex = nil
                        },
                        onZoomChanged: { scale in
                            viewModel.zoomScale = scale
                        },
                        onStrokePositionChanged: { pageIndex, yPosition in
                            viewModel.updateActiveQuestion(pageIndex: pageIndex, yPosition: yPosition)
                        },
                        onContainerCreated: { container in
                            viewModel.containerView = container
                        }
                    )
                    .onChange(of: scrollToPageIndex) { _, newValue in
                        if newValue != nil {
                            DispatchQueue.main.async {
                                scrollToPageIndex = nil
                            }
                        }
                    }

                    if viewModel.showSidebar {
                        CanvasSidebarView(
                            isDarkMode: viewModel.isDarkMode,
                            transcriptionService: viewModel.handwritingService,
                            tutorEvalService: viewModel.tutorEvalService,
                            tutorModeOn: viewModel.tutorModeOn,
                            activeQuestionLabel: viewModel.activeQuestionLabel
                        )
                        .frame(width: metrics.canvasSidebarWidth)
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.showSidebar)
                .ignoresSafeArea(edges: .bottom)
            }

            // Ruler overlay
            if viewModel.showRuler {
                CanvasRulerOverlayView(isDarkMode: viewModel.isDarkMode)
                    .transition(.opacity)
            }

            // Calculator overlay (floating, no backdrop)
            if viewModel.showCalculator {
                CalculatorView(
                    viewModel: viewModel.calculatorViewModel,
                    isDarkMode: viewModel.isDarkMode,
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showCalculator = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(50)
            }

            // Tutor overlays — kept alive to cache KaTeX WKWebView content
            if let step = viewModel.currentHintStep {
                TutorHintCard(
                    hintText: step.explanation,
                    stepLabel: "Step \(viewModel.currentTutorStepIndex + 1)",
                    isDarkMode: viewModel.isDarkMode,
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showHintPopover = false
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 100)
                .padding(.trailing, 16)
                .opacity(viewModel.showHintPopover ? 1 : 0)
                .allowsHitTesting(viewModel.showHintPopover)
                .zIndex(51)

                TutorRevealCard(
                    workText: step.work,
                    stepLabel: "Step \(viewModel.currentTutorStepIndex + 1)",
                    isDarkMode: viewModel.isDarkMode,
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showRevealPopover = false
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 100)
                .padding(.trailing, 16)
                .opacity(viewModel.showRevealPopover ? 1 : 0)
                .allowsHitTesting(viewModel.showRevealPopover)
                .zIndex(52)
            }

            // Add Color popup (centered overlay, CLAUDE.md pattern)
            if viewModel.showAddColor {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showAddColor = false
                        }
                    }

                CanvasAddColorPopup(
                    onAdd: { color in
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.addColor(color)
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showAddColor = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Export preview overlay
            if viewModel.showExportPreview, let data = viewModel.exportedPDFData {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.dismissExportPreview()
                        }
                    }

                ExportPreviewView(
                    pdfData: data,
                    documentName: viewModel.document.displayName,
                    onShare: {
                        viewModel.shareExportedPDF()
                    },
                    onDismiss: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.dismissExportPreview()
                        }
                    }
                )
                .frame(maxWidth: 600, maxHeight: 700)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: viewModel.showRuler)
        .animation(.spring(duration: 0.2), value: viewModel.showAddColor)
        .animation(.spring(duration: 0.25), value: viewModel.showExportPreview)
        .animation(.spring(duration: 0.2), value: viewModel.showCalculator)
        .animation(.spring(duration: 0.2), value: viewModel.showHintPopover)
        .animation(.spring(duration: 0.2), value: viewModel.showRevealPopover)
        .alert("Clear All Strokes?", isPresented: $viewModel.showClearConfirmation) {
            Button("Clear", role: .destructive) {
                viewModel.clearAllStrokes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all drawings on every page.")
        }
        .onAppear {
            viewModel.startBatteryMonitoring()
            viewModel.startWifiMonitoring()
            viewModel.drawingManager.onDrawingChanged = { [weak viewModel] in
                guard let viewModel else { return }
                autoSaveTask?.cancel()
                autoSaveTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    viewModel.saveCanvasState()
                }
                // Live transcription — when sidebar is open OR tutor mode is on
                if viewModel.showSidebar || viewModel.tutorModeOn {
                    let drawing = viewModel.drawingManager.drawing(for: viewModel.currentPageIndex)
                    let regions = viewModel.activeSubquestionRegions()
                    viewModel.handwritingService.onDrawingChanged(
                        drawing: drawing,
                        activeRegions: regions
                    )
                }
                // Tutor evaluation is triggered reactively via .onChange(of: latexResult) below
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            viewModel.tickStudyTimer()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            viewModel.updateBatteryLevel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.saveCanvasState()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.exportedPDFURL != nil },
            set: { if !$0 { viewModel.exportedPDFURL = nil } }
        )) {
            if let url = viewModel.exportedPDFURL {
                ShareSheet(url: url)
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
