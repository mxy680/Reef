//
//  CanvasView.swift
//  Reef
//

import SwiftUI
import PDFKit

struct CanvasView: View {
    let note: Note
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var isViewingCanvas: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    // Drawing state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor: Color = .inkBlack
    @State private var penWidth: StrokeWidth = .medium
    @State private var highlighterWidth: StrokeWidth = .medium
    @State private var eraserSize: EraserSize = .medium

    // Undo/Redo state
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // Lasso selection state
    @State private var hasSelection: Bool = false

    // Reference to canvas for undo/redo
    @State private var canvasViewRef: CanvasContainerView?

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var fileURL: URL {
        FileStorageService.shared.getFileURL(
            for: note.id,
            fileExtension: note.fileExtension
        )
    }

    var body: some View {
        ZStack {
            // Document with drawing canvas overlay
            DrawingOverlayView(
                documentURL: fileURL,
                fileType: note.fileType,
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                penWidth: $penWidth,
                highlighterWidth: $highlighterWidth,
                eraserSize: $eraserSize,
                isDarkMode: themeManager.isDarkMode,
                onCanvasReady: { canvasViewRef = $0 },
                onUndoStateChanged: { canUndo = $0 },
                onRedoStateChanged: { canRedo = $0 },
                onSelectionChanged: { hasSelection = $0 }
            )

            // Floating toolbar at bottom
            VStack {
                Spacer()
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    selectedColor: $selectedColor,
                    penWidth: $penWidth,
                    highlighterWidth: $highlighterWidth,
                    eraserSize: $eraserSize,
                    colorScheme: effectiveColorScheme,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    hasSelection: hasSelection,
                    onHomePressed: { dismiss() },
                    onUndo: { canvasViewRef?.canvasView.undoManager?.undo() },
                    onRedo: { canvasViewRef?.canvasView.undoManager?.redo() },
                    onCut: { /* TODO: Implement cut */ },
                    onCopy: { /* TODO: Implement copy */ },
                    onDelete: { /* TODO: Implement delete */ }
                )
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .background(themeManager.isDarkMode ? Color.black : Color(white: 0.96))
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            columnVisibility = .detailOnly
            isViewingCanvas = true
        }
        .onDisappear {
            columnVisibility = .all
            isViewingCanvas = false
        }
    }
}

// MARK: - PDF View

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground

        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Image Document View

struct ImageDocumentView: View {
    let url: URL
    let colorScheme: ColorScheme
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                } else {
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        Task.detached {
            guard let data = try? Data(contentsOf: url),
                  let loadedImage = UIImage(data: data) else { return }

            await MainActor.run {
                image = loadedImage
            }
        }
    }
}

// MARK: - Unsupported Document View

struct UnsupportedDocumentView: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.5))

            Text("Unsupported document type")
                .font(.quicksand(18, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
