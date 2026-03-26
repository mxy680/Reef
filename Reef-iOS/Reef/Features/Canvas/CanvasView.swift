import SwiftUI
import PencilKit
import Combine

// MARK: - Canvas View (fullscreen container)

struct CanvasView: View {
    @Bindable var viewModel: CanvasViewModel
    var walkthroughStep: WalkthroughStep? = nil
    let onDismiss: () -> Void

    @State private var scrollToPageIndex: Int? = nil
    @State private var autoSaveTask: Task<Void, Never>?

    @Environment(\.reefLayoutMetrics) private var metrics

    var body: some View {
        ZStack {
            // Background
            (viewModel.isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
                .ignoresSafeArea()

            if !viewModel.isReady {
                // Loading screen — wait for PDF + answer keys
                CanvasLoadingView(
                    isLoadingAnswerKeys: viewModel.isLoadingAnswerKeys,
                    documentName: viewModel.document.displayName,
                    onClose: {
                        viewModel.stopAllAudio()
                        viewModel.cancelAllTasks()
                        onDismiss()
                    }
                )
            } else {

            VStack(spacing: 0) {
                // Toolbar — always full width
                VStack(spacing: 0) {
                    CanvasInfoStrip(
                        viewModel: viewModel,
                        walkthroughStep: walkthroughStep,
                        onClose: {
                            viewModel.stopAllAudio()
                            viewModel.saveCanvasState()
                            onDismiss()
                        }
                    )

                    CanvasDrawingBar(
                        viewModel: viewModel,
                        drawingManager: viewModel.drawingManager,
                        onScrollToPage: { index in
                            scrollToPageIndex = index
                        },
                        walkthroughStep: walkthroughStep
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
                .ignoresSafeArea(edges: .horizontal)
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
                        rulerActive: viewModel.showRuler,
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
                            viewModel: viewModel,
                            onSendChat: { message in
                                viewModel.sendTutorChat(message)
                            }
                        )
                        .frame(width: metrics.canvasSidebarWidth)
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.showSidebar)
                .ignoresSafeArea(edges: [.bottom, .horizontal])
            }

            // Ruler is handled natively by PKCanvasView.isRulerActive

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

            // Debug prompt panel
            if viewModel.showDebugPrompt {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("LLM Prompt Debug")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.showDebugPrompt = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))

                    ScrollView {
                        // Live transcription debug info
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STEP: \(viewModel.currentTutorStepIndex + 1)/\(viewModel.tutorStepCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.yellow)
                            Text("LATEX: \(viewModel.handwritingService.latexResult.prefix(100))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        Text("Transcription + answer key only. Eval disabled.")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .background(Color.black.opacity(0.9))
                }
                .frame(width: 420, height: 500)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 100)
                .padding(.leading, 8)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(60)
            }

            // Hint/reveal now shown inline in sidebar — popovers removed

            // Bug report popup
            if viewModel.showBugReport {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showBugReport = false
                        }
                    }

                BugReportPopup(
                    documentId: viewModel.document.id,
                    questionLabel: viewModel.activeQuestionLabel,
                    onDismiss: {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.showBugReport = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(100)
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
        } // end else (isReady)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: viewModel.showRuler)
        .animation(.spring(duration: 0.2), value: viewModel.showBugReport)
        .animation(.spring(duration: 0.2), value: viewModel.showAddColor)
        .animation(.spring(duration: 0.25), value: viewModel.showExportPreview)
        .animation(.spring(duration: 0.2), value: viewModel.showCalculator)
        .animation(.spring(duration: 0.2), value: viewModel.showDebugPrompt)
        // Hint/reveal animations handled in sidebar
        .alert("Clear Everything?", isPresented: $viewModel.showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAllStrokes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all drawings, tutor progress, and chat history for every question. This cannot be undone.")
        }
        .alert("Reset This Question?", isPresented: $viewModel.showResetQuestionConfirmation) {
            Button("Reset", role: .destructive) {
                viewModel.resetCurrentQuestion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all strokes and tutor progress for this question.")
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
                // Track shape/highlighter strokes so they're excluded from transcription
                if viewModel.selectedTool == .shapes || viewModel.selectedTool == .highlighter {
                    let drawing = viewModel.drawingManager.drawing(for: viewModel.currentPageIndex)
                    viewModel.markShapeStrokes(in: drawing)
                }

                // Update the polling service's drawing snapshot (polled every 400ms)
                if viewModel.showSidebar || viewModel.tutorModeOn {
                    viewModel.handwritingService.currentDrawing = viewModel.drawingWithoutShapes(for: viewModel.currentPageIndex)
                    viewModel.handwritingService.currentRegions = viewModel.activeSubquestionRegions()
                }
            }

            // Start transcription polling (400ms interval)
            if viewModel.showSidebar || viewModel.tutorModeOn {
                viewModel.handwritingService.startPolling()
            }
        }
        .onChange(of: viewModel.tutorModeOn) { _, isOn in
            if isOn {
                viewModel.handwritingService.startPolling()
            } else {
                viewModel.handwritingService.stopPolling()
            }
        }
        .onDisappear {
            viewModel.stopAllAudio()
            viewModel.handwritingService.stopPolling()
            viewModel.cancelAllTasks()
            autoSaveTask?.cancel()
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

