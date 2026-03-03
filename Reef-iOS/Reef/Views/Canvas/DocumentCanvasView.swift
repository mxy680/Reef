//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen scrollable PDF viewer
//

import SwiftUI

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @State private var viewModel = CanvasViewModel()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor: ToolbarColor = .black

    /// Toolbar teal — matches ReefColors.primary
    private static let barColor = ReefColors.primary

    private static let cream = Color(hex: 0xF8F0E6)

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen canvas
            if viewModel.isLoading {
                loadingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Self.cream)
            } else if let error = viewModel.error {
                errorView(error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Self.cream)
            } else if let pdf = viewModel.pdfDocument {
                CanvasPageView(pdfDocument: pdf)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Self.cream)
                    .ignoresSafeArea()

                // Floating toolbar overlay
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    selectedColor: $selectedColor,
                    onClose: { onDismiss() }
                )
                .dashboardCard()
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
        }
        .task {
            #if DEBUG
            if document.id == "dev-test" {
                viewModel.loadTestDocument()
                return
            }
            #endif
            await viewModel.loadDocument(document)
        }
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
