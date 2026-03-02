import SwiftUI
import PencilKit

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @State private var viewModel = CanvasViewModel()
    @State private var undoManager: UndoManager?

    var body: some View {
        ZStack {
            Color(hex: 0xF5F5F0)
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                VStack(spacing: 0) {
                    CanvasToolbar(
                        documentName: document.displayName,
                        fingerDrawing: viewModel.fingerDrawing,
                        onClose: {
                            viewModel.saveCurrentDrawings()
                            onDismiss()
                        },
                        onUndo: { undoManager?.undo() },
                        onRedo: { undoManager?.redo() },
                        onToggleFingerDrawing: {
                            viewModel.fingerDrawing.toggle()
                        }
                    )

                    // Canvas area
                    if let page = viewModel.currentPage {
                        CanvasPageView(
                            pdfPage: page,
                            fingerDrawing: viewModel.fingerDrawing,
                            drawing: Binding(
                                get: { viewModel.currentDrawing },
                                set: { viewModel.currentDrawing = $0 }
                            )
                        )
                        .id(viewModel.currentPageIndex)
                        .onAppear {
                            // Capture the undo manager from the environment
                            undoManager = UndoManager()
                        }
                    }

                    if viewModel.pageCount > 1 {
                        PageNavigationBar(
                            currentPage: viewModel.currentPageIndex,
                            pageCount: viewModel.pageCount,
                            onPrevious: { viewModel.previousPage() },
                            onNext: { viewModel.nextPage() }
                        )
                    }
                }
            }
        }
        .task { await viewModel.loadDocument(document) }
        .onDisappear { viewModel.saveCurrentDrawings() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ReefColors.primary)

            Text("Loading document...")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(ReefColors.gray600)
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

            // Close button
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
