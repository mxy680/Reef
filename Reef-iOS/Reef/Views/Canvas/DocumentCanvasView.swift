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
    @State private var showRuler = false
    @State private var showPageSettings = false
    @State private var pageOverlaySettings = PageOverlaySettings()

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
                        .transition(.opacity)
                } else if let error = viewModel.error {
                    errorView(error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Self.cream)
                        .transition(.opacity)
                } else if let pdf = viewModel.pdfDocument {
                    CanvasToolbar(
                        selectedTool: $selectedTool,
                        currentQuestionIndex: $currentQuestionIndex,
                        questionCount: isReconstructed
                            ? (document.problemCount ?? 1)
                            : 1,
                        onClose: { onDismiss() },
                        tutorModeOn: $tutorModeOn,
                        isReconstructed: isReconstructed,
                        documentName: document.displayName,
                        showRuler: $showRuler,
                        showPageSettings: $showPageSettings,
                        hasActiveOverlay: pageOverlaySettings.type != .none,
                        pageOverlaySettings: $pageOverlaySettings
                    )
                    .zIndex(1)

                    if tutorModeOn && isReconstructed {
                        TutorStepToolbar(questionIndex: currentQuestionIndex)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ZStack {
                        CanvasPageView(
                            pdfDocument: pdf,
                            pageRange: pageRange(for: currentQuestionIndex),
                            overlaySettings: pageOverlaySettings
                        )
                        .id(currentQuestionIndex)

                        if showRuler {
                            RulerOverlayView()
                                .transition(.opacity)
                        }
                    }
                    .background(Self.cream)
                    .overlay {
                        // Tap-to-dismiss layer (covers canvas only, not toolbar)
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
            .animation(.easeInOut(duration: 0.2), value: showRuler)
        }
        .animation(.spring(duration: 0.2), value: showPageSettings)
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
