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

    var body: some View {
        ZStack {
            Color(hex: 0xF5F5F0)
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if let pdf = viewModel.pdfDocument {
                VStack(spacing: 0) {
                    CanvasToolbar(
                        documentName: document.displayName,
                        onClose: { onDismiss() }
                    )

                    CanvasPageView(pdfDocument: pdf)
                }
            }
        }
        .task { await viewModel.loadDocument(document) }
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
