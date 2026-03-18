import SwiftUI
import PencilKit

// MARK: - Canvas View (fullscreen container)

struct CanvasView: View {
    @Bindable var viewModel: CanvasViewModel
    let onDismiss: () -> Void

    @State private var drawingManager = CanvasDrawingManager()

    var body: some View {
        ZStack {
            // Background
            (viewModel.isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                VStack(spacing: 0) {
                    CanvasInfoStrip(
                        viewModel: viewModel,
                        onClose: onDismiss
                    )

                    CanvasDrawingBar(viewModel: viewModel)

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

                // PDF + Drawing area
                CanvasPageView(
                    pdfDocument: viewModel.pdfDocument,
                    drawingManager: drawingManager,
                    currentTool: viewModel.activePKTool,
                    darkMode: viewModel.isDarkMode,
                    overlayType: viewModel.overlaySettings.type,
                    overlaySpacing: viewModel.overlaySettings.spacing,
                    overlayOpacity: viewModel.overlaySettings.opacity,
                    onCanvasTouchBegan: {
                        viewModel.dismissAllPopovers()
                    },
                    onZoomChanged: { scale in
                        viewModel.zoomScale = scale
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            }

            // Ruler overlay
            if viewModel.showRuler {
                CanvasRulerOverlayView(isDarkMode: viewModel.isDarkMode)
                    .transition(.opacity)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showRuler)
        .animation(.spring(duration: 0.2), value: viewModel.showAddColor)
    }
}
