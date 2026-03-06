//
//  DocumentCanvasView.swift
//  Reef
//
//  Full-screen scrollable PDF viewer
//

import SwiftUI
import UIKit

struct DocumentCanvasView: View {
    let document: Document
    let onDismiss: () -> Void

    @State private var viewModel = CanvasViewModel()
    @State private var selectedTool: CanvasTool = .pen
    @State private var currentQuestionIndex = 0
    @State private var tutorModeOn = false

    private var isReconstructed: Bool {
        document.questionPages != nil
    }

    private static let cream = Color(hex: 0xF8F0E6)

    /// Tab strip = barColor (0x4E8A97) darkened 18% for safe area.
    /// RGB: (78,138,151) * 0.82 ≈ (64,113,124)
    private static let safeAreaColor = Color(red: 64/255.0, green: 113/255.0, blue: 124/255.0)

    var body: some View {
        ZStack {
            // Full-bleed tab strip teal so the safe area is never black
            Self.safeAreaColor.ignoresSafeArea()

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
                        currentQuestionIndex: $currentQuestionIndex,
                        questionCount: isReconstructed
                            ? (document.problemCount ?? 1)
                            : (pdf.pageCount),
                        onClose: { onDismiss() },
                        tutorModeOn: $tutorModeOn,
                        isReconstructed: isReconstructed
                    )

                    if tutorModeOn && isReconstructed {
                        TutorStepToolbar(questionIndex: currentQuestionIndex)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    CanvasPageView(
                        pdfDocument: pdf,
                        pageRange: pageRange(for: currentQuestionIndex)
                    )
                    .id(currentQuestionIndex)
                    .background(Self.cream)
                }
            }
            .animation(.spring(duration: 0.25), value: tutorModeOn)
        }
        .ignoresSafeArea()
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

    // MARK: - Page Range

    private func pageRange(for questionIndex: Int) -> ClosedRange<Int>? {
        if let pages = document.questionPages,
           questionIndex < pages.count,
           pages[questionIndex].count == 2 {
            return pages[questionIndex][0]...pages[questionIndex][1]
        }
        // Non-reconstructed: each tab = one page (0-indexed)
        if !isReconstructed {
            return questionIndex...questionIndex
        }
        return nil
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
