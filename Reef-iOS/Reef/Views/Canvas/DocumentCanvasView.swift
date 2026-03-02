//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen canvas for viewing and annotating documents
//

import SwiftUI

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @State private var viewModel = CanvasViewModel()

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
                        currentTool: viewModel.currentTool,
                        currentColor: viewModel.currentColor,
                        fingerDrawing: viewModel.fingerDrawing,
                        canUndo: viewModel.canUndo,
                        canRedo: viewModel.canRedo,
                        onClose: {
                            viewModel.saveCurrentDrawings()
                            onDismiss()
                        },
                        onUndo: { viewModel.undo() },
                        onRedo: { viewModel.redo() },
                        onSelectTool: { tool in
                            viewModel.currentTool = tool
                            switch tool {
                            case .pen: viewModel.currentLineWidth = 3.0
                            case .highlighter: viewModel.currentLineWidth = 15.0
                            case .eraser: viewModel.currentLineWidth = 30.0
                            }
                        },
                        onSelectColor: { color in
                            viewModel.currentColor = color
                        },
                        onToggleFingerDrawing: {
                            viewModel.fingerDrawing.toggle()
                        }
                    )

                    // Canvas area
                    if let page = viewModel.currentPage {
                        CanvasPageView(
                            pdfPage: page,
                            fingerDrawing: viewModel.fingerDrawing,
                            tool: viewModel.currentTool,
                            strokeColor: viewModel.currentColor,
                            lineWidth: viewModel.currentLineWidth,
                            strokes: viewModel.currentDrawing.strokes,
                            onDrawingAction: { action in
                                viewModel.handleDrawingAction(action)
                            }
                        )
                        .id(viewModel.currentPageIndex)
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
