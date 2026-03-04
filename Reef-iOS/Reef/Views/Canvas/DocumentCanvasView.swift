//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen scrollable PDF viewer
//

import SwiftUI
import UIKit

/// Sets the UIKit container background behind a fullScreenCover so the
/// safe area (camera housing on iPad) shows the correct color instead of black.
private struct ContainerBackgroundSetter: UIViewRepresentable {
    let color: UIColor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let v = ancestor {
                v.backgroundColor = color
                ancestor = v.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @State private var viewModel = CanvasViewModel()
    @State private var selectedTool: CanvasTool = .pen

    private static let cream = Color(hex: 0xF8F0E6)

    /// Toolbar teal — must match CanvasToolbar.barColor so the
    /// safe area (camera housing) is teal, not black.
    private static let barColor = Color(hex: 0x4E8A97)
    private static let barUIColor = UIColor(red: 0x4E/255.0, green: 0x8A/255.0, blue: 0x97/255.0, alpha: 1)

    var body: some View {
        ZStack {
            // Full-bleed teal so the safe area (camera housing) is never black
            Self.barColor.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Self.cream)
                } else if let error = viewModel.error {
                    errorView(error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Self.cream)
                } else if let pdf = viewModel.pdfDocument {
                    CanvasToolbar(
                        selectedTool: $selectedTool,
                        onClose: { onDismiss() }
                    )

                    CanvasPageView(pdfDocument: pdf)
                        .background(Self.cream)
                }
            }
        }
        .ignoresSafeArea()
        .background(ContainerBackgroundSetter(color: Self.barUIColor))
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
