//
//  CanvasView.swift
//  Reef
//

import SwiftUI
import PDFKit
import PencilKit

struct CanvasView: View {
    let note: Note
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var isViewingCanvas: Bool
    var onDismiss: (() -> Void)? = nil
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Drawing state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedPenColor: Color = UserDefaults.standard.bool(forKey: "isDarkMode") ? .white : .black
    @State private var selectedHighlighterColor: Color = Color(red: 1.0, green: 0.92, blue: 0.23) // Yellow
    @State private var penWidth: CGFloat = StrokeWidthRange.penDefault
    @State private var highlighterWidth: CGFloat = StrokeWidthRange.highlighterDefault
    @State private var eraserSize: CGFloat = StrokeWidthRange.eraserDefault
    @State private var eraserType: EraserType = .stroke
    @State private var diagramWidth: CGFloat = StrokeWidthRange.diagramDefault
    @State private var diagramAutosnap: Bool = true
    @State private var customPenColors: [Color] = []
    @State private var customHighlighterColors: [Color] = []
    @State private var canvasBackgroundMode: CanvasBackgroundMode = .normal
    @State private var canvasBackgroundOpacity: CGFloat = 0.15
    @State private var canvasBackgroundSpacing: CGFloat = 48

    // Assignment Mode state
    @State private var assignmentModeState: AssignmentModeState = .inactive
    @State private var questionSet: QuestionSet?
    @State private var currentQuestionIndex: Int = 0

    // Reference to canvas
    @State private var canvasViewRef: CanvasContainerView?

    // Drawing persistence
    @State private var saveTask: Task<Void, Never>?

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var fileURL: URL {
        FileStorageService.shared.getFileURL(
            for: note.id,
            fileExtension: note.fileExtension
        )
    }

    /// The URL to display - either original document or current question PDF
    private var displayURL: URL {
        if assignmentModeState.isActive,
           let qs = questionSet,
           currentQuestionIndex < qs.questions.count {
            let sortedQuestions = qs.questions.sorted { $0.orderIndex < $1.orderIndex }
            return sortedQuestions[currentQuestionIndex].fileURL
        }
        return fileURL
    }

    /// Current question for display (1-indexed)
    private var currentQuestion: Int {
        currentQuestionIndex + 1
    }

    /// Total number of questions
    private var totalQuestions: Int {
        questionSet?.questions.count ?? 0
    }

    /// Document ID for the current view - stable ID for each question to preserve drawings
    private var currentDocumentID: UUID {
        if assignmentModeState.isActive,
           let qs = questionSet,
           currentQuestionIndex < qs.questions.count {
            let sortedQuestions = qs.questions.sorted { $0.orderIndex < $1.orderIndex }
            return sortedQuestions[currentQuestionIndex].id
        }
        return note.id
    }

    var body: some View {
        ZStack {
            // Document with drawing canvas overlay
            DrawingOverlayView(
                documentID: currentDocumentID,
                documentURL: displayURL,
                fileType: assignmentModeState.isActive ? .pdf : note.fileType,
                selectedTool: $selectedTool,
                selectedPenColor: $selectedPenColor,
                selectedHighlighterColor: $selectedHighlighterColor,
                penWidth: $penWidth,
                highlighterWidth: $highlighterWidth,
                eraserSize: $eraserSize,
                eraserType: $eraserType,
                diagramWidth: $diagramWidth,
                diagramAutosnap: $diagramAutosnap,
                canvasBackgroundMode: canvasBackgroundMode,
                canvasBackgroundOpacity: canvasBackgroundOpacity,
                canvasBackgroundSpacing: canvasBackgroundSpacing,
                isDarkMode: themeManager.isDarkMode,
                onCanvasReady: { container in
                    canvasViewRef = container
                }
            )

            // Floating toolbar at bottom
            VStack {
                Spacer()
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    selectedPenColor: $selectedPenColor,
                    selectedHighlighterColor: $selectedHighlighterColor,
                    penWidth: $penWidth,
                    highlighterWidth: $highlighterWidth,
                    eraserSize: $eraserSize,
                    eraserType: $eraserType,
                    diagramWidth: $diagramWidth,
                    diagramAutosnap: $diagramAutosnap,
                    customPenColors: $customPenColors,
                    customHighlighterColors: $customHighlighterColors,
                    canvasBackgroundMode: $canvasBackgroundMode,
                    canvasBackgroundOpacity: $canvasBackgroundOpacity,
                    canvasBackgroundSpacing: $canvasBackgroundSpacing,
                    colorScheme: effectiveColorScheme,
                    onHomePressed: {
                        if let onDismiss = onDismiss {
                            // Use parent-controlled animation
                            onDismiss()
                        } else {
                            // Fallback for navigation-based usage
                            dismiss()
                        }
                    },
                    onAIPressed: { /* TODO: Implement AI assistant */ },
                    onToggleDarkMode: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.toggle()
                        }
                        // Update pen color to match new theme
                        selectedPenColor = themeManager.isDarkMode ? .white : .black
                    },
                    isDocumentAIReady: note.isAIReady,
                    onAddPageAfterCurrent: {
                        canvasViewRef?.addPageAfterCurrent()
                    },
                    onAddPageToEnd: {
                        canvasViewRef?.addPageToEnd()
                    },
                    onDeleteCurrentPage: {
                        canvasViewRef?.deleteCurrentPage()
                    },
                    onClearCurrentPage: {
                        canvasViewRef?.clearCurrentPage()
                    },
                    assignmentModeState: $assignmentModeState,
                    onAssignmentModeToggle: toggleAssignmentMode,
                    onPreviousQuestion: goToPreviousQuestion,
                    onNextQuestion: goToNextQuestion
                )
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .background(themeManager.isDarkMode ? Color.black : Color(white: 0.96))
        .preferredColorScheme(effectiveColorScheme)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Only manage state if not controlled by parent (onDismiss provided)
            if onDismiss == nil {
                columnVisibility = .detailOnly
                isViewingCanvas = true
            }
            // Set default pen color based on theme
            selectedPenColor = themeManager.isDarkMode ? .white : .black
        }
        .onDisappear {
            // Only manage state if not controlled by parent
            if onDismiss == nil {
                columnVisibility = .all
                isViewingCanvas = false
            }
        }
        .task {
            // Check if we have an existing question set for this note
            loadExistingQuestionSet()
        }
    }

    // MARK: - Assignment Mode

    private func loadExistingQuestionSet() {
        if let existing = QuestionExtractionService.shared.getQuestionSet(
            for: note.id,
            modelContext: modelContext
        ), existing.isReady {
            questionSet = existing
        }
    }

    private func toggleAssignmentMode() {
        switch assignmentModeState {
        case .inactive:
            // Check if we have cached questions
            if let qs = questionSet, qs.isReady {
                // Use cached questions
                currentQuestionIndex = 0
                assignmentModeState = .active(
                    currentQuestion: 1,
                    totalQuestions: qs.questionCount
                )
            } else {
                // Need to extract questions
                extractQuestions()
            }

        case .loading:
            // Can't toggle while loading
            break

        case .active:
            // Return to normal mode
            assignmentModeState = .inactive
            currentQuestionIndex = 0
        }
    }

    private func extractQuestions() {
        assignmentModeState = .loading

        Task {
            do {
                let qs = try await QuestionExtractionService.shared.extractQuestions(
                    from: note,
                    modelContext: modelContext
                )

                await MainActor.run {
                    questionSet = qs
                    currentQuestionIndex = 0

                    if qs.questionCount > 0 {
                        assignmentModeState = .active(
                            currentQuestion: 1,
                            totalQuestions: qs.questionCount
                        )
                    } else {
                        // No questions found
                        assignmentModeState = .inactive
                    }
                }
            } catch {
                await MainActor.run {
                    print("Question extraction failed: \(error)")
                    assignmentModeState = .inactive
                }
            }
        }
    }

    private func goToPreviousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
        updateAssignmentModeState()
    }

    private func goToNextQuestion() {
        guard currentQuestionIndex < totalQuestions - 1 else { return }
        currentQuestionIndex += 1
        updateAssignmentModeState()
    }

    private func updateAssignmentModeState() {
        assignmentModeState = .active(
            currentQuestion: currentQuestion,
            totalQuestions: totalQuestions
        )
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
