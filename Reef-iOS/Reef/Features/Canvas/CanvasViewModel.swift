import SwiftUI
import PencilKit
import PDFKit
import UIKit
import AVFoundation
@preconcurrency import Supabase

// MARK: - Canvas ViewModel

@Observable
@MainActor
final class CanvasViewModel {
    let document: Document

    // MARK: - PDF

    var pdfDocument: PDFDocument
    var isLoadingPDF: Bool = true  // Set true synchronously — loadPDF task clears it
    var pdfError: String?
    private var loadPDFTask: Task<Void, Never>?
    private var loadAnswerKeysTask: Task<Void, Never>?
    private var stepSpeechTask: Task<Void, Never>?

    // MARK: - Tool State

    let drawingManager = CanvasDrawingManager()
    var selectedTool: CanvasToolType = .pen
    var penColor: UIColor = .black
    var penWidth: CGFloat = 2.0
    var highlighterColor: UIColor = UIColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1)
    var highlighterWidth: CGFloat = 4.0
    var shapesColor: UIColor = .black
    var shapesWidth: CGFloat = 2.0
    var eraserMode: PKEraserTool.EraserType = .vector
    var eraserWidth: CGFloat = 8.0
    var customColors: [UIColor] = []
    var customHighlighterColors: [UIColor] = []
    var customShapesColors: [UIColor] = []

    /// The active PKTool derived from current settings.
    var activePKTool: PKTool {
        let color: UIColor
        let width: CGFloat
        switch selectedTool {
        case .highlighter:
            color = highlighterColor
            width = highlighterWidth
        case .shapes:
            color = shapesColor
            width = shapesWidth
        default:
            color = penColor
            width = penWidth
        }
        return selectedTool.pkTool(
            color: color,
            width: width,
            eraserType: eraserMode,
            eraserWidth: eraserWidth
        )
    }

    /// When true on the simulator, touch input pans instead of drawing.
    #if targetEnvironment(simulator)
    var simulatorPanMode = false
    #endif

    var activeDrawingPolicy: PKCanvasViewDrawingPolicy {
        // The iOS Simulator does not support Apple Pencil input. Using `.anyInput` allows
        // touch/mouse drawing during development so the canvas is testable without real hardware.
        // On device, only Pencil input is accepted (unless the hand-draw tool is active).
        #if targetEnvironment(simulator)
        return simulatorPanMode ? .pencilOnly : .anyInput
        #else
        return selectedTool == .handDraw ? .anyInput : .pencilOnly
        #endif
    }

    // MARK: - Page State

    var currentPageIndex: Int = 0
    var pageVersion: Int = 0
    var zoomScale: CGFloat = 1.0
    var overlaySettings: CanvasOverlaySettings = CanvasOverlaySettings()
    var originalPageCount: Int = 0
    var addedPageIndices: [Int] = []
    private var savedState: CanvasDocumentData?

    var pageCount: Int {
        pdfDocument.pageCount
    }

    // MARK: - Battery

    // MARK: - Study Timer

    var studySeconds: Int = 0
    private let sessionStart = Date()

    var studyTimerLabel: String {
        let h = studySeconds / 3600
        let m = (studySeconds % 3600) / 60
        let s = studySeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func tickStudyTimer() {
        studySeconds = Int(Date().timeIntervalSince(sessionStart))
    }

    var batteryLevel: Float = 1.0

    var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }

    /// Asset name for the battery icon based on current level.
    var batteryIconName: String {
        switch batteryLevel {
        case ..<0.15: "battery.1"
        case ..<0.40: "battery.2"
        case ..<0.70: "battery.3"
        default:       "battery.4"
        }
    }

    func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = max(UIDevice.current.batteryLevel, 0)
        // On simulator batteryLevel is -1; show full
        if batteryLevel < 0 { batteryLevel = 1.0 }
    }

    func updateBatteryLevel() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level >= 0 ? level : 1.0
    }

    // MARK: - UI State

    var showPageControls: Bool = false
    var showRuler: Bool = false
    var isDarkMode: Bool = false
    var showSidebar: Bool = false
    var activeQuestionLabel: String?
    var isMicOn: Bool = false
    /// Stroke bounds drawn with the shape tool — excluded from transcription.
    private var shapeStrokeBounds: Set<CGRect> = []
    private var audioRecorder: AVAudioRecorder?
    private var micSilenceTimer: Task<Void, Never>?
    var showCalculator: Bool = false
    let calculatorViewModel = CalculatorViewModel()
    let syncService = CanvasSyncService()
    let tutorEvalService = TutorEvaluationService()
    private var evalDebounceWork: DispatchWorkItem?
    private var strokeWriteWork: DispatchWorkItem?
    /// True while applying remote strokes from Realtime — suppresses onDrawingChanged
    var isApplyingRemoteStrokes: Bool = false
    var showClearConfirmation: Bool = false
    var showResetQuestionConfirmation: Bool = false
    var showBugReport: Bool = false
    var isExporting: Bool = false
    var exportedPDFData: Data?
    var exportedPDFURL: URL?
    var showExportPreview: Bool = false
    weak var containerView: CanvasContainerView?

    // MARK: - Popover State

    var showToolSettings: Bool = false
    var showEraserSettings: Bool = false
    var showPageSettings: Bool = false
    var showPageMenu: Bool = false
    var showAddColor: Bool = false

    // Popover anchor positions (global midX)
    var selectedToolMidX: CGFloat = 0
    var pageSettingsMidX: CGFloat = 0
    var pageMenuMidX: CGFloat = 0

    // MARK: - Connection State

    var isWifiConnected: Bool = false
    private var wifiTask: Task<Void, Never>?

    func startWifiMonitoring() {
        isWifiConnected = WifiMonitor.shared.isConnected
        wifiTask?.cancel()
        wifiTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { break }
                self.isWifiConnected = WifiMonitor.shared.isConnected
            }
        }
    }

    // MARK: - Tutor State

    var tutorModeOn: Bool = false
    /// When true, tutor mode won't auto-enable on answer key load (walkthrough controls it)
    var deferTutorMode: Bool = false
    var currentTutorStepIndex: Int = 0
    var currentQuestionIndex: Int = 0
    var showHintPopover: Bool = false
    var showRevealPopover: Bool = false
    var tutorVoiceEnabled: Bool = true  // Whether tutor speaks out loud (vs chat-only)
    var showDebugPrompt: Bool = false
    var debugTapCount: Int = 0
    var debugTapResetTask: Task<Void, Never>?
    // Bbox debug overlay removed
    var hintMidX: CGFloat = 0
    var revealMidX: CGFloat = 0

    // Answer key data
    var answerKeys: [Int: QuestionAnswer] = [:]
    var isLoadingAnswerKeys: Bool = true
    private var savedTutorProgress: [String: TutorStepState]?

    /// Whether this document has been reconstructed (has answer keys available)
    var isReconstructed: Bool {
        document.problemCount != nil && (document.problemCount ?? 0) > 0
    }

    /// True when both PDF and answer keys are loaded
    var isReady: Bool {
        !isLoadingPDF && !isLoadingAnswerKeys
    }

    /// Derives question number and part label from activeQuestionLabel.
    var activeQuestionNumber: Int {
        guard let label = activeQuestionLabel, label.hasPrefix("Q") else { return 1 }
        var numStr = ""
        for ch in label.dropFirst() {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        return Int(numStr) ?? 1
    }

    private var activePartLabel: String? {
        guard let label = activeQuestionLabel, label.hasPrefix("Q") else { return nil }
        var partStr = ""
        var pastNum = false
        for ch in label.dropFirst() {
            if ch.isNumber { pastNum = true } else if pastNum { partStr.append(ch) }
        }
        return partStr.isEmpty ? nil : partStr
    }

    var currentAnswerKey: QuestionAnswer? {
        answerKeys[activeQuestionNumber]
    }

    var currentSteps: [AnswerKeyStep] {
        guard let ak = currentAnswerKey else { return [] }
        // Find steps for the active part label
        if let partLabel = activePartLabel {
            for part in ak.parts {
                if part.label == partLabel { return part.steps }
                for sub in part.parts {
                    if sub.label == partLabel { return sub.steps }
                }
            }
        }
        // Fallback: first part or top-level steps
        if let firstPart = ak.parts.first, !firstPart.steps.isEmpty {
            return firstPart.steps
        }
        return ak.steps
    }

    var tutorStepCount: Int { currentSteps.count }

    var currentHintStep: AnswerKeyStep? {
        guard currentTutorStepIndex < currentSteps.count else { return nil }
        return currentSteps[currentTutorStepIndex]
    }

    var currentTutorStepLabel: String {
        guard currentTutorStepIndex < currentSteps.count else { return "" }
        return currentSteps[currentTutorStepIndex].description
    }

    var tutorProgress: Double {
        guard tutorStepCount > 0 else { return 0 }
        let completedSteps = Double(currentTutorStepIndex)
        let intraStepProgress = tutorEvalService.stepProgress

        // If we're on the last step and it's completed, show 100%
        if currentTutorStepIndex == tutorStepCount - 1 && tutorEvalService.status == "completed" {
            return 1.0
        }

        return (completedSteps + intraStepProgress) / Double(tutorStepCount)
    }

    var canSkipStep: Bool { currentTutorStepIndex < tutorStepCount - 1 }
    var canGoBackStep: Bool { currentTutorStepIndex > 0 }

    func skipCurrentStep() {
        guard canSkipStep else { return }
        tutorEvalService.resetForNextStep()
        currentTutorStepIndex += 1
        updatePendingReinforcement()
    }

    func goToPreviousStep() {
        guard canGoBackStep else { return }
        tutorEvalService.resetForNextStep()
        currentTutorStepIndex -= 1
        updatePendingReinforcement()
    }

    /// Called on every drawing change (fires per stroke point from PencilKit).
    /// Debounces both stroke writes (500ms) and eval (1500ms).
    private var strokeUpsertWork: DispatchWorkItem?

    func onDrawingChanged(forPage pageOverride: Int? = nil) {
        guard !isApplyingRemoteStrokes else { return }

        let page = pageOverride ?? currentPageIndex

        // ~100ms debounce to detect pen lift (fires once after last point)
        strokeUpsertWork?.cancel()
        let upsertWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let drawing = self.drawingWithoutShapes(for: page)
            let strokes = CanvasSyncService.extractStrokePayloads(from: drawing)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.syncService.writeStrokes(
                    documentId: self.document.id,
                    questionLabel: self.activeQuestionLabel ?? "Q1a",
                    pageIndex: page,
                    strokes: strokes
                )
            }
        }
        strokeUpsertWork = upsertWork
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: upsertWork)

        // 250ms after last point: request transcription from server
        strokeWriteWork?.cancel()
        let txWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.requestTranscription()
            }
        }
        strokeWriteWork = txWork
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: txWork)

        // After last stroke: fire tutor eval
        // Use longer delay (5s) if in mistake state to give student time to fix
        if tutorModeOn {
            let delay = tutorEvalService.status == "mistake" ? 5000 : 900
            evalDebounceWork?.cancel()
            let evalWork = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.tutorModeOn else { return }
                    await self.fireEval()
                }
            }
            evalDebounceWork = evalWork
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: evalWork)
        }
    }

    func cancelAllTasks() {
        loadPDFTask?.cancel()
        loadAnswerKeysTask?.cancel()
        stepSpeechTask?.cancel()
        evalDebounceWork?.cancel()
        strokeWriteWork?.cancel()
        syncService.stopPolling()
    }

    /// Sleep without participating in cooperative task cancellation.
    /// Task.sleep sets Task.isCancelled as a side effect, which kills debounce tasks.
    private func safeSleep(milliseconds: Int) async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) {
                cont.resume()
            }
        }
    }

    func stopAllAudio() {
        tutorEvalService.stopAudio()
    }

    // MARK: - Transcription

    /// Request server to transcribe strokes from canvas_strokes → student_work
    private func requestTranscription() async {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/transcribe") else { return }
        guard let token = try? await supabase.auth.session.accessToken else { return }

        let label = activeQuestionLabel ?? "Q1a"
        struct TxRequest: Encodable {
            let document_id: String
            let question_label: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(TxRequest(document_id: document.id, question_label: label))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            struct TxResponse: Decodable { let latex: String }
            if let result = try? JSONDecoder().decode(TxResponse.self, from: data) {
                print("[transcribe] \(label): \(result.latex.prefix(50))")
            }
        } catch {
            print("[transcribe] Failed: \(error)")
        }
    }

    // MARK: - Eval

    private func fireEval() async {
        syncService.lastLocalEvalTime = Date()
        let (qNum, partLabel) = parseQuestionLabel()
        guard qNum > 0 else { return }

        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/tutor-evaluate") else { return }
        guard let token = try? await supabase.auth.session.accessToken else { return }

        struct EvalRequest: Encodable {
            let documentId: String
            let questionNumber: Int
            let partLabel: String?
            let stepIndex: Int
            let isDemo: Bool
            let studentImage: String?

            enum CodingKeys: String, CodingKey {
                case documentId = "document_id"
                case questionNumber = "question_number"
                case partLabel = "part_label"
                case stepIndex = "step_index"
                case isDemo = "is_demo"
                case studentImage = "student_image"
            }
        }

        let body = EvalRequest(
            documentId: document.id,
            questionNumber: qNum,
            partLabel: partLabel,
            stepIndex: currentTutorStepIndex,
            isDemo: tutorEvalService.isDemo,
            studentImage: captureActiveQuestionImage()
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(body)

        // The response will be written to chat_history by the server,
        // and Realtime will push it to us. But we also process the response
        // directly for immediate UI update.
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }

            struct EvalResponse: Decodable {
                let progress: Double
                let status: String
                let mistakeExplanation: String?
                let stepsCompleted: Int
                let speechAudio: String?
                let speechText: String?

                enum CodingKeys: String, CodingKey {
                    case progress, status
                    case mistakeExplanation = "mistake_explanation"
                    case stepsCompleted = "steps_completed"
                    case speechAudio = "speech_audio"
                    case speechText = "speech_text"
                }
            }

            let evalResponse = try JSONDecoder().decode(EvalResponse.self, from: data)
            await tutorEvalService.processEvalResponse(
                progress: evalResponse.progress,
                status: evalResponse.status,
                mistakeExplanation: evalResponse.mistakeExplanation,
                stepsCompleted: evalResponse.stepsCompleted,
                speechAudio: evalResponse.speechAudio,
                speechText: evalResponse.speechText
            )

            if evalResponse.status == "completed" {
                advanceTutorSteps(count: evalResponse.stepsCompleted)
            }
        } catch {
            print("[eval] Failed: \(error)")
        }
    }

    func loadAnswerKeys(forceLoad: Bool = false) async {
        // Always subscribe to Realtime on first call (regardless of reconstruction state)
        if syncService.pollTimer == nil {
            syncService.startPolling(documentId: document.id)
        }

        guard isReconstructed || forceLoad else {
            // Don't clear isLoadingAnswerKeys — loadPDF will call us again with forceLoad
            // once reconstruction completes
            return
        }
        isLoadingAnswerKeys = true
        let repo = SupabaseAnswerKeyRepository()

        // Restore active question from Supabase (most recently updated stroke row)
        if activeQuestionLabel == nil {
            if let userId = try? await supabase.auth.session.user.id.uuidString {
                struct LabelRow: Decodable { let questionLabel: String
                    enum CodingKeys: String, CodingKey { case questionLabel = "question_label" }
                }
                let row: LabelRow? = try? await supabase
                    .from("canvas_strokes")
                    .select("question_label")
                    .eq("user_id", value: userId)
                    .eq("document_id", value: document.id)
                    .order("updated_at", ascending: false)
                    .limit(1)
                    .single()
                    .execute().value
                activeQuestionLabel = row?.questionLabel
            }
            if activeQuestionLabel == nil { activeQuestionLabel = "Q1a" }
        }
        let targetQuestion = activeQuestionNumber

        // Poll every 5s for up to 5 minutes — wait until Q1's key specifically exists
        var attempts = 0
        var result = await repo.fetchAnswerKeys(documentId: document.id)
        while result.answers[targetQuestion] == nil && attempts < 60 && !Task.isCancelled {
            attempts += 1
            answerKeys = result.answers
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            result = await repo.fetchAnswerKeys(documentId: document.id)
        }

        answerKeys = result.answers
        isLoadingAnswerKeys = false

        if !deferTutorMode && answerKeys[targetQuestion] != nil, let label = activeQuestionLabel {
            currentTutorStepIndex = 0
            tutorEvalService.resetForNextStep()
            updatePendingReinforcement()
            tutorModeOn = true
            showSidebar = true
            restoreTutorStateForLabel(label)
        }
    }

    // MARK: - Toolbar Layout

    var toolbarRowMinX: CGFloat = 0
    var toolbarRowWidth: CGFloat = 0

    // MARK: - Init

    init(document: Document) {
        self.document = document
        self.pdfDocument = MockCanvasData.blankPDF()
        let loaded = CanvasStorageService.load(documentId: document.id)
        self.savedState = loaded

        // Tutor state is loaded from Supabase, not local storage
        self.savedTutorProgress = nil

        tutorEvalService.voiceEnabled = tutorVoiceEnabled

        tutorEvalService.onMistakeSpoken = { [weak self] in
            guard let self, self.tutorVoiceEnabled, !self.isMicOn else { return }
            self.toggleMic()
        }

        tutorEvalService.onAnswerKeyUpdated = { [weak self] in
            guard let self else { return }
            self.loadAnswerKeysTask?.cancel()
            self.loadAnswerKeysTask = Task { @MainActor in
                await self.loadAnswerKeys()
                // loadAnswerKeys handles state restoration internally
            }
        }

        // Restore tutor state from Supabase on initial load
        syncService.onInitialTutorStateLoaded = { [weak self] rows in
            guard let self else { return }
            for row in rows {
                let step = row.tutorStep ?? 0
                let progress = row.tutorProgress ?? 0
                let status = row.tutorStatus ?? "idle"
                // Cache in-memory for question switching
                self.savedTutorProgress?[row.questionLabel] = TutorStepState(
                    currentStepIndex: step,
                    stepEvaluation: StepEvaluation(
                        progress: progress,
                        status: status,
                        mistakeExplanation: nil
                    ),
                    lastTranscription: "",
                    chatMessages: nil
                )
                // Apply to current question immediately
                if row.questionLabel == self.activeQuestionLabel {
                    self.currentTutorStepIndex = min(step, max(0, self.tutorStepCount - 1))
                    self.tutorEvalService.stepProgress = progress
                    self.tutorEvalService.status = status
                }
            }
            if self.savedTutorProgress == nil { self.savedTutorProgress = [:] }
        }

        // Wire Realtime stroke sync — REPLACE canvas with external strokes (from simulator)
        syncService.onStrokesUpdated = { [weak self] row in
            guard let self else { return }
            let page = row.pageIndex
            guard let container = self.containerView, page < container.canvasViews.count else { return }

            // Build PKDrawing from stroke data (1:1 coordinates — no scale)
            let ink = PKInk(.pen, color: .black)
            var drawing = PKDrawing()

            for strokeData in row.strokes {
                guard !strokeData.x.isEmpty, strokeData.x.count == strokeData.y.count else { continue }
                let points = zip(strokeData.x, strokeData.y).enumerated().map { idx, pair in
                    PKStrokePoint(
                        location: CGPoint(x: pair.0, y: pair.1),
                        timeOffset: TimeInterval(idx) * 0.01,
                        size: CGSize(width: 3, height: 3),
                        opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 4
                    )
                }
                let path = PKStrokePath(controlPoints: points, creationDate: Date())
                drawing.strokes.append(PKStroke(ink: ink, path: path))
            }

            // REPLACE the entire page drawing (not append)
            self.isApplyingRemoteStrokes = true
            self.drawingManager.setDrawing(drawing, for: page)
            container.canvasViews[page].drawing = drawing
            self.isApplyingRemoteStrokes = false
        }

        // Wire Realtime stroke delete — clear canvas
        syncService.onStrokesDeleted = { [weak self] in
            guard let self, let container = self.containerView else { return }
            print("[Realtime] Clearing all canvas pages")
            self.isApplyingRemoteStrokes = true
            for i in 0..<container.canvasViews.count {
                self.drawingManager.setDrawing(PKDrawing(), for: i)
                container.canvasViews[i].drawing = PKDrawing()
            }
            self.isApplyingRemoteStrokes = false
        }

        // Wire Realtime chat sync
        syncService.onChatMessageReceived = { [weak self] row in
            guard let self else { return }
            guard row.questionLabel == self.activeQuestionLabel else { return }
            guard let role = TutorChatMessage.Role(rawValue: row.role) else { return }
            // Skip if we already have this message (from direct eval response)
            if !self.tutorEvalService.chatMessages.contains(where: { $0.latex == row.text && $0.role == role }) {
                self.tutorEvalService.chatMessages.append(
                    TutorChatMessage(role: role, latex: row.text, timestamp: Date())
                )
                // Play TTS for tutor replies received via polling (e.g., from simulator)
                // Skip TTS during initial history load — those are old messages
                if role == .answer && self.tutorEvalService.voiceEnabled && !self.syncService.isLoadingHistory {
                    let ttsText = (row.speechText?.isEmpty == false) ? row.speechText! : row.text
                    Task { await self.tutorEvalService.speakText(ttsText) }
                }
            }
        }

        // Wire tutor state changes from polling (progress, step advancement)
        syncService.onTutorStateChanged = { [weak self] row in
            guard let self else { return }
            guard row.questionLabel == self.activeQuestionLabel else { return }
            let progress = row.tutorProgress ?? 0
            let status = row.tutorStatus ?? "idle"
            let stepsCompleted = row.tutorStepsCompleted ?? 1

            // Update progress bar
            self.tutorEvalService.stepProgress = progress
            self.tutorEvalService.status = status

            // Speak TTS if there's speech text (only from external sources like simulator)
            // Skip if we just fired an eval locally — processEvalResponse already played the audio
            if let speechText = row.tutorSpeechText, !speechText.isEmpty,
               self.tutorEvalService.voiceEnabled,
               self.syncService.lastLocalEvalTime == nil || Date().timeIntervalSince(self.syncService.lastLocalEvalTime!) > 10.0 {
                Task {
                    await self.tutorEvalService.speakText(speechText)
                }
            }

            // Advance step if completed
            if status == "completed" {
                self.advanceTutorSteps(count: stepsCompleted)
            }
        }

        // Bbox debug overlay removed

        loadPDFTask = Task { await loadPDF() }
        loadAnswerKeysTask = Task { await loadAnswerKeys() }
    }

    private static let pdfSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    private func loadPDF() async {

        isLoadingPDF = true
        pdfError = nil
        do {
            let repo = SupabaseDocumentRepository()

            // If document is still processing, poll until completed (up to 5 min)
            var isReconstructedDoc = document.status == .completed && (document.problemCount ?? 0) > 0
            if document.status == .processing {
                var attempts = 0
                while attempts < 60 && !Task.isCancelled {
                    attempts += 1
                    try? await Task.sleep(for: .seconds(5))
                    if let updated = try? await repo.getDocument(document.id),
                       updated.status != .processing {
                        isReconstructedDoc = updated.status == .completed && (updated.problemCount ?? 0) > 0
                        break
                    }
                }
            }

            // Only fetch output.pdf if reconstruction completed successfully
            let signedURL = try await repo.getDownloadURL(document.id, preferOutput: isReconstructedDoc)
            let (data, _) = try await Self.pdfSession.data(from: signedURL)
            guard let pdf = PDFDocument(data: data) else {
                pdfError = "Unable to open PDF"
                isLoadingPDF = false
                return
            }
            pdfDocument = pdf
            originalPageCount = pdf.pageCount

            if let saved = savedState {
                print("[CanvasVM] Restoring: \(saved.drawingDataByPage.count) drawings, overlay=\(saved.overlaySettings.type.rawValue)")
                overlaySettings = saved.overlaySettings
                currentPageIndex = min(saved.currentPageIndex, pdf.pageCount - 1)

                // Restore added blank pages in ascending index order
                for index in saved.addedPageIndices.sorted() {
                    if index <= pdfDocument.pageCount {
                        let blankPage = createBlankPage()
                        pdfDocument.insert(blankPage, at: index)
                    }
                }
                addedPageIndices = saved.addedPageIndices

                // Restore per-page drawings (suppress onDrawingChanged to avoid re-saving)
                let savedCallback = drawingManager.onDrawingChanged
                drawingManager.onDrawingChanged = nil
                for (key, data) in saved.drawingDataByPage {
                    guard let pageIndex = Int(key) else { continue }
                    do {
                        let drawing = try PKDrawing(data: data)
                        drawingManager.setDrawing(drawing, for: pageIndex)
                    } catch {
                        print("[CanvasVM] Failed to decode drawing for page \(pageIndex): \(error)")
                    }
                }
                drawingManager.onDrawingChanged = savedCallback
                print("[CanvasVM] Restored \(saved.drawingDataByPage.count) drawings")

                savedState = nil
            }

            // Single pageVersion bump AFTER all state is restored
            // so setupPages reads the restored drawings
            pageVersion += 1

            // If document finished reconstruction, kick off answer key loading
            // (the initial loadAnswerKeys() may have skipped because isReconstructed was false at init)
            if isReconstructedDoc && answerKeys.isEmpty {
                loadAnswerKeysTask?.cancel()
                loadAnswerKeysTask = Task { await loadAnswerKeys(forceLoad: true) }
            } else if !isReconstructedDoc {
                // No reconstruction = no answer keys to wait for — unblock the canvas
                isLoadingAnswerKeys = false
            }
        } catch {
            pdfError = "Failed to download document"
            isLoadingAnswerKeys = false  // Unblock canvas to show error
        }
        isLoadingPDF = false
    }

    // MARK: - Question Region Detection

    func updateActiveQuestion(pageIndex: Int, yPosition: Double) {
        // Update current page index so region filtering uses the correct page
        currentPageIndex = pageIndex

        let originalPage = originalPageIndex(for: pageIndex)
        let newLabel = QuestionRegionTracker.activeLabel(
            forPage: originalPage,
            yPosition: yPosition,
            questionRegions: document.questionRegions,
            questionPages: document.questionPages
        )

        // On question change: save current state, cancel in-flight eval, restore new question's state
        if newLabel != activeQuestionLabel {
            // Save outgoing question's tutor state
            if let oldLabel = activeQuestionLabel, tutorModeOn {
                saveTutorStateForLabel(oldLabel)
            }

            // Cancel any in-flight evaluation so stale results don't corrupt the new question
            tutorEvalService.resetForNextStep()

            activeQuestionLabel = newLabel

            // Restore incoming question's tutor state
            if let label = newLabel {
                restoreTutorStateForLabel(label)
            }
        }
    }

    /// Save current tutor state into the in-memory cache for a given label.
    private func saveTutorStateForLabel(_ label: String) {
        if savedTutorProgress == nil { savedTutorProgress = [:] }
        savedTutorProgress?[label] = TutorStepState(
            currentStepIndex: currentTutorStepIndex,
            stepEvaluation: StepEvaluation(
                progress: tutorEvalService.stepProgress,
                status: tutorEvalService.status,
                mistakeExplanation: tutorEvalService.mistakeExplanation
            ),
            lastTranscription: "",
            chatMessages: nil  // Chat is sourced from DB, not local storage
        )
    }

    /// Restore tutor state from saved data for a given label.
    private func restoreTutorStateForLabel(_ label: String) {
        guard let state = savedTutorProgress?[label] else {
            // No saved state — reset to beginning
            currentTutorStepIndex = 0
            tutorEvalService.resetForNextStep()
            return
        }

        currentTutorStepIndex = min(state.currentStepIndex, max(0, tutorStepCount - 1))

        if let eval = state.stepEvaluation {
            tutorEvalService.stepProgress = eval.progress
            tutorEvalService.status = eval.status
            tutorEvalService.mistakeExplanation = eval.mistakeExplanation
        }

        // Chat messages are loaded from the DB via polling preload — don't restore from local storage

    }

    /// Returns only the active SUBquestion's regions for stroke filtering.
    /// e.g. if activeQuestionLabel is "Q2a", returns only regions with label "a" for Q2.
    func activeSubquestionRegions() -> [PartRegion]? {
        guard let label = activeQuestionLabel,
              let qPages = document.questionPages,
              let qRegions = document.questionRegions else { return nil }

        // Parse "Q2a" → questionIndex=1, partLabel="a"
        // Format: Q<number><label>
        guard label.hasPrefix("Q"), label.count >= 3 else { return nil }
        let numAndLabel = label.dropFirst() // "2a"
        var numStr = ""
        var partLabel = ""
        for ch in numAndLabel {
            if ch.isNumber {
                numStr.append(ch)
            } else {
                partLabel.append(ch)
            }
        }
        guard let qNum = Int(numStr), qNum >= 1 else { return nil }
        let qi = qNum - 1

        guard qi < qPages.count, qi < qRegions.count,
              let data = qRegions[qi] else { return nil }

        // Filter to only the matching part label (or nil for stem)
        let targetLabel = partLabel.isEmpty ? nil : partLabel
        return data.regions.filter { $0.label == targetLabel }
    }

    /// Map current page index back to original index, accounting for added blank pages.
    private func originalPageIndex(for currentIndex: Int) -> Int {
        let addedBefore = addedPageIndices.filter { $0 <= currentIndex }.count
        return currentIndex - addedBefore
    }

    // MARK: - Actions

    func dismissAllPopovers() {
        showToolSettings = false
        showEraserSettings = false
        showPageSettings = false
        showPageMenu = false
        showPageControls = false
        // Note: hint and reveal popovers are NOT dismissed here —
        // user closes them manually via X button
    }

    func exportDocument() {
        guard !isExporting, let container = containerView else { return }
        isExporting = true

        // If dark mode, temporarily switch to light for export
        let wasDarkMode = isDarkMode
        if wasDarkMode {
            isDarkMode = false
            container.applyDarkMode(false)
        }

        // Screenshot each page — WYSIWYG, no coordinate math
        let data = CanvasExportService.exportFromContainer(container)

        // Restore dark mode
        if wasDarkMode {
            isDarkMode = true
            container.applyDarkMode(true)
        }

        exportedPDFData = data
        showExportPreview = true
        isExporting = false
    }

    func shareExportedPDF() {
        guard let data = exportedPDFData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(document.displayName).pdf")
        try? data.write(to: tempURL)
        exportedPDFURL = tempURL
    }

    func dismissExportPreview() {
        showExportPreview = false
        exportedPDFData = nil
        exportedPDFURL = nil
    }

    func toolRetapped(_ tool: CanvasToolType) {
        dismissAllPopovers()
        if tool == .eraser {
            showEraserSettings = true
        } else if tool.hasSettings {
            showToolSettings = true
        }
    }

    /// Speak the current step description via TTS (only if voice enabled).
    func speakCurrentStepDescription() {
        guard tutorVoiceEnabled else { return }
        guard currentTutorStepIndex < currentSteps.count else { return }
        let step = currentSteps[currentTutorStepIndex]
        // Use tutor_speech if available (LLM-generated, plain English), fall back to description
        let speech = step.tutorSpeech?.isEmpty == false
            ? step.tutorSpeech!
            : "Next up: " + step.description

        stepSpeechTask?.cancel()
        stepSpeechTask = Task { [weak self] in
            guard let self,
                  let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                  let url = URL(string: "\(serverURL)/ai/walkthrough-tts"),
                  let token = try? await supabase.auth.session.accessToken else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": speech])

            guard !Task.isCancelled else { return }

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            guard !Task.isCancelled else { return }

            struct TTSResponse: Decodable {
                let speechAudio: String?
                enum CodingKeys: String, CodingKey { case speechAudio = "speech_audio" }
            }

            guard let result = try? JSONDecoder().decode(TTSResponse.self, from: data),
                  let audioBase64 = result.speechAudio,
                  let audioData = Data(base64Encoded: audioBase64) else { return }

            self.tutorEvalService.playAudio(audioData)
        }
    }

    /// Advance by multiple steps at once (handles step skipping).
    /// Shows reinforcement for each skipped step before advancing.
    func advanceTutorSteps(count: Int) {
        let remaining = tutorStepCount - currentTutorStepIndex
        let stepsToAdvance = min(count, remaining)

        for _ in 0..<stepsToAdvance {
            // Only advance — reinforcement is handled by TutorEvaluationService
            // (shows only the most recent one, not stacked)
            if currentTutorStepIndex < tutorStepCount - 1 {
                currentTutorStepIndex += 1
                tutorEvalService.resetForNextStep()
                updatePendingReinforcement()
            }
        }

        // If we completed all steps, mark as done (don't reset — let status stay "completed")
        if currentTutorStepIndex >= tutorStepCount - 1 && stepsToAdvance >= remaining {
            stepSpeechTask?.cancel()
            tutorEvalService.stepProgress = 1.0
            tutorEvalService.status = "completed"
        } else if stepsToAdvance > 0 {
            // Fire eval for the new step — the student's work is already on canvas
            evalDebounceWork?.cancel()
            let advanceWork = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    print("[step-advance] FIRING eval for new step \(self.currentTutorStepIndex)")
                    await self.fireEval()
                }
            }
            evalDebounceWork = advanceWork
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000), execute: advanceWork)
        }
    }

    func advanceTutorStep() {
        advanceTutorSteps(count: 1)
    }

    func resetTutorSteps() {
        currentTutorStepIndex = 0
        showHintPopover = false
        showRevealPopover = false
        tutorEvalService.reset()
    }

    /// Ordered list of all question labels in the document (e.g. ["Q1a", "Q1b", "Q2a", ...]).
    var allQuestionLabels: [String] {
        guard let qPages = document.questionPages,
              let qRegions = document.questionRegions else { return [] }

        var labels: [String] = []
        for (qi, _) in qPages.enumerated() {
            let qNum = qi + 1
            if qi < qRegions.count, let data = qRegions[qi] {
                // Collect unique part labels in order
                var seen = Set<String>()
                for region in data.regions {
                    let partLabel = region.label ?? "a"
                    let full = "Q\(qNum)\(partLabel)"
                    if seen.insert(full).inserted {
                        labels.append(full)
                    }
                }
            } else {
                labels.append("Q\(qNum)a")
            }
        }
        return labels
    }

    /// Whether there is a previous question/subquestion to go back to.
    var canGoToPreviousQuestion: Bool {
        guard let label = activeQuestionLabel else { return false }
        let labels = allQuestionLabels
        guard let idx = labels.firstIndex(of: label) else { return false }
        return idx > 0
    }

    /// Whether there is a next question/subquestion to skip to.
    var canSkipToNextQuestion: Bool {
        guard let label = activeQuestionLabel else { return !allQuestionLabels.isEmpty }
        let labels = allQuestionLabels
        guard let idx = labels.firstIndex(of: label) else { return false }
        return idx < labels.count - 1
    }

    /// Skip to the next question/subquestion. Returns the page index to scroll to, or nil.
    func skipToNextQuestion() -> Int? {
        let labels = allQuestionLabels
        let currentLabel = activeQuestionLabel ?? ""
        let currentIdx = labels.firstIndex(of: currentLabel) ?? -1
        let nextIdx = currentIdx + 1
        guard nextIdx < labels.count else { return nil }

        let nextLabel = labels[nextIdx]

        // Save current question's tutor state
        if let old = activeQuestionLabel, tutorModeOn {
            saveTutorStateForLabel(old)
        }

        // Parse next label to find its page
        guard nextLabel.hasPrefix("Q"), nextLabel.count >= 2 else { return nil }
        let numAndLabel = nextLabel.dropFirst()
        var numStr = ""
        for ch in numAndLabel {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        guard let qNum = Int(numStr), qNum >= 1,
              let qPages = document.questionPages,
              qNum - 1 < qPages.count else { return nil }

        let pageRange = qPages[qNum - 1]
        guard pageRange.count >= 2 else { return nil }

        // Reset tutor state for the new question
        activeQuestionLabel = nextLabel
        evalDebounceWork?.cancel()
        currentTutorStepIndex = 0
        tutorEvalService.resetForNextStep()
        restoreTutorStateForLabel(nextLabel)

        return pageRange[0] // scroll to the question's start page
    }

    /// Go back to the previous question/subquestion.
    func goToPreviousQuestion() {
        let labels = allQuestionLabels
        let currentLabel = activeQuestionLabel ?? ""
        guard let currentIdx = labels.firstIndex(of: currentLabel), currentIdx > 0 else { return }

        let prevLabel = labels[currentIdx - 1]

        // Save current question's tutor state
        if let old = activeQuestionLabel, tutorModeOn {
            saveTutorStateForLabel(old)
        }

        activeQuestionLabel = prevLabel
        evalDebounceWork?.cancel()
        currentTutorStepIndex = 0
        tutorEvalService.resetForNextStep()
        restoreTutorStateForLabel(prevLabel)
    }

    /// Reset all work for the current question: erase strokes on its pages, clear all DB rows
    /// (strokes + chat) for every sub-question, and reset tutor progress.
    func resetCurrentQuestion() {
        guard let container = containerView else { return }

        let label = activeQuestionLabel ?? "Q1a"
        guard let qPages = document.questionPages else { return }

        // Parse label to get question number
        guard label.hasPrefix("Q"), label.count >= 2 else { return }
        var numStr = ""
        for ch in label.dropFirst() {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        guard let qNum = Int(numStr), qNum >= 1, qNum - 1 < qPages.count else { return }

        let pageRange = qPages[qNum - 1]
        guard pageRange.count >= 2 else { return }

        // Collect all sub-question labels for this question (Q1a, Q1b, Q1c, ...)
        let prefix = "Q\(qNum)"
        let subLabels = allQuestionLabels.filter { $0.hasPrefix(prefix) }

        // Clear strokes on question's pages (original indices → actual indices accounting for added pages)
        let savedCallback = drawingManager.onDrawingChanged
        drawingManager.onDrawingChanged = nil
        for origPageIdx in pageRange[0]...pageRange[1] {
            let addedBefore = addedPageIndices.filter { $0 <= origPageIdx }.count
            let actualPageIdx = origPageIdx + addedBefore
            if actualPageIdx < container.canvasViews.count {
                drawingManager.setDrawing(PKDrawing(), for: actualPageIdx)
                container.canvasViews[actualPageIdx].drawing = PKDrawing()
            }
        }
        drawingManager.onDrawingChanged = savedCallback
        drawingManager.onDrawingChanged?()

        // Cancel pending debounce work so stale transcription/eval doesn't fire
        strokeUpsertWork?.cancel()
        strokeWriteWork?.cancel()
        evalDebounceWork?.cancel()

        // Reset tutor state for this question
        currentTutorStepIndex = 0
        tutorEvalService.reset()

        // Clear saved progress for all sub-questions
        if savedTutorProgress != nil {
            savedTutorProgress = savedTutorProgress?.filter { !$0.key.hasPrefix(prefix) }
        }

        clearShapeStrokes()
        saveCanvasState()

        // Clear canvas strokes + chat history from Supabase for ALL sub-questions.
        // Clear chat twice: once immediately, then again after 3s to catch any
        // server-side writes from in-flight eval requests that land after the first clear.
        print("[Reset] Clearing DB for labels=\(subLabels) doc=\(document.id.prefix(12))")
        Task {
            await syncService.clearStrokesForQuestion(documentId: document.id, questionLabels: subLabels)
            await syncService.clearChatForQuestion(documentId: document.id, questionLabels: subLabels)
            print("[Reset] First DB clear complete, waiting 3s for in-flight evals...")
            try? await Task.sleep(for: .seconds(3))
            await syncService.clearChatForQuestion(documentId: document.id, questionLabels: subLabels)
            print("[Reset] Second DB clear complete")
        }
    }

    /// Track new strokes added with the shape tool.
    func markShapeStrokes(in drawing: PKDrawing) {
        for stroke in drawing.strokes {
            shapeStrokeBounds.insert(stroke.renderBounds)
        }
    }

    /// Return a filtered drawing with shape strokes removed (for transcription only).
    func drawingWithoutShapes(for pageIndex: Int) -> PKDrawing {
        let drawing = drawingManager.drawing(for: pageIndex)
        guard !shapeStrokeBounds.isEmpty else { return drawing }

        let filtered = drawing.strokes.filter { stroke in
            !shapeStrokeBounds.contains(stroke.renderBounds)
        }
        var newDrawing = PKDrawing()
        for stroke in filtered {
            newDrawing.strokes.append(stroke)
        }
        return newDrawing
    }

    /// Clear shape stroke tracking (called on clear/reset).
    func clearShapeStrokes() {
        shapeStrokeBounds.removeAll()
    }

    /// Capture a JPEG snapshot of the student's drawing for the active question region.
    /// Returns base64-encoded JPEG or nil if no strokes in the region.
    func captureActiveQuestionImage() -> String? {
        let drawing = drawingManager.drawing(for: currentPageIndex)
        guard !drawing.strokes.isEmpty else { return nil }

        // Get the question region bounds, or use the full drawing bounds
        let bounds: CGRect
        if let regions = activeSubquestionRegions(), !regions.isEmpty {
            let minY = regions.map(\.yStart).min() ?? 0
            let maxY = regions.map(\.yEnd).max() ?? 0
            // Use full page width, cropped to question Y range
            let drawingBounds = drawing.bounds
            bounds = CGRect(
                x: drawingBounds.minX - 10,
                y: CGFloat(minY) - 10,
                width: drawingBounds.width + 20,
                height: CGFloat(maxY - minY) + 20
            )
        } else {
            bounds = drawing.bounds.insetBy(dx: -10, dy: -10)
        }

        guard bounds.width > 0, bounds.height > 0 else { return nil }

        // Render drawing with white background (PKDrawing.image has transparent bg → black in JPEG)
        let scale: CGFloat = 2.0
        let pixelSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: pixelSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixelSize))
            let drawingImage = drawing.image(from: bounds, scale: scale)
            drawingImage.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.5) else { return nil }

        // Skip if image is tiny (likely empty/noise)
        guard jpegData.count > 500 else { return nil }

        return jpegData.base64EncodedString()
    }

    /// Set the pending reinforcement text from the current step's answer key.
    private func updatePendingReinforcement() {
        if currentTutorStepIndex < currentSteps.count {
            tutorEvalService.pendingReinforcement = currentSteps[currentTutorStepIndex].reinforcement
        } else {
            tutorEvalService.pendingReinforcement = nil
        }
    }

    private var micTempURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("reef_voice.m4a")
    }

    func toggleMic() {
        if isMicOn {
            // Stop recording and transcribe
            micSilenceTimer?.cancel()
            micSilenceTimer = nil
            audioRecorder?.stop()
            audioRecorder = nil
            isMicOn = false

            let url = micTempURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }

            Task {
                do {
                    let text = try await uploadAudioForTranscription(fileURL: url)
                    if !text.isEmpty {
                        sendTutorChat(text)
                    }
                } catch {
                    tutorEvalService.chatMessages.append(TutorChatMessage(
                        role: .error, latex: "Voice message failed. Try again.", timestamp: Date()
                    ))
                }
                try? FileManager.default.removeItem(at: url)
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        } else {
            // Start recording
            let permission = AVAudioApplication.shared.recordPermission
            if permission == .granted {
                startMicRecording()
            } else {
                Task {
                    let granted = await withCheckedContinuation { cont in
                        AVAudioApplication.requestRecordPermission { g in
                            cont.resume(returning: g)
                        }
                    }
                    if granted {
                        startMicRecording()
                    }
                }
            }
        }
    }

    private func startMicRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = micTempURL
            try? FileManager.default.removeItem(at: url)

            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ])
            recorder.isMeteringEnabled = true
            recorder.record()
            audioRecorder = recorder
            isMicOn = true

            // Voice activity detection: poll audio levels to auto-stop
            micSilenceTimer = Task { [weak self] in
                var speechDetected = false
                var silenceStart: Date?
                let speechThreshold: Float = -25  // dB — above this = speech
                let noSpeechTimeout: TimeInterval = 2.0
                let endOfSpeechTimeout: TimeInterval = 1.5
                var logCounter = 0

                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, !Task.isCancelled, self.isMicOn,
                          let rec = self.audioRecorder else { return }

                    rec.updateMeters()
                    let level = rec.averagePower(forChannel: 0)

                    // Log every 500ms for debugging
                    logCounter += 1
                    if logCounter % 5 == 0 {
                        print("[mic-vad] level=\(String(format: "%.1f", level))dB speech=\(speechDetected) silence=\(silenceStart != nil)")
                    }

                    if level > speechThreshold {
                        // Speech detected
                        speechDetected = true
                        silenceStart = nil
                    } else if speechDetected {
                        // Had speech, now silent — start counting
                        if silenceStart == nil { silenceStart = Date() }
                        if Date().timeIntervalSince(silenceStart!) >= endOfSpeechTimeout {
                            self.toggleMic()
                            return
                        }
                    } else {
                        // Never detected speech — timeout after 2s
                        if silenceStart == nil { silenceStart = Date() }
                        if Date().timeIntervalSince(silenceStart!) >= noSpeechTimeout {
                            self.toggleMic()
                            return
                        }
                    }
                }
            }
        } catch {
            isMicOn = false
        }
    }

    private func uploadAudioForTranscription(fileURL: URL) async throws -> String {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/ai/transcribe-audio") else {
            throw URLError(.badURL)
        }

        let audioData = try Data(contentsOf: fileURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let authSession = try await supabase.auth.session
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "VoiceUpload", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(200))"
            ])
        }

        struct TranscribeResponse: Decodable { let text: String }
        return try JSONDecoder().decode(TranscribeResponse.self, from: data).text
    }

    /// Send a chat message to the tutor.
    func sendTutorChat(_ message: String) {
        syncService.lastLocalChatTime = Date()
        let label = activeQuestionLabel ?? "Q1a"
        guard label.hasPrefix("Q"), label.count >= 2 else { return }
        let numAndLabel = label.dropFirst()
        var numStr = ""
        var partLabel = ""
        for ch in numAndLabel {
            if ch.isNumber { numStr.append(ch) } else { partLabel.append(ch) }
        }
        guard let qNum = Int(numStr) else { return }

        tutorEvalService.sendChat(
            message: message,
            documentId: document.id,
            questionNumber: qNum,
            partLabel: partLabel.isEmpty ? nil : partLabel,
            stepIndex: currentTutorStepIndex,
            studentLatex: "",
            studentImage: captureActiveQuestionImage()
        )
    }

    /// Normalize LaTeX for comparison: strip delimiters, whitespace, common wrappers.
    private func normalizeLatex(_ latex: String) -> String {
        var s = latex
        // Strip display math delimiters
        s = s.replacingOccurrences(of: "$$", with: "")
        s = s.replacingOccurrences(of: "\\[", with: "")
        s = s.replacingOccurrences(of: "\\]", with: "")
        s = s.replacingOccurrences(of: "\\(", with: "")
        s = s.replacingOccurrences(of: "\\)", with: "")
        s = s.replacingOccurrences(of: "$", with: "")
        // Strip whitespace
        s = s.replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "\n", with: "")
        s = s.replacingOccurrences(of: "\t", with: "")
        return s.lowercased()
    }

    /// Parse activeQuestionLabel "Q2a" → (questionNumber: 2, partLabel: "a")
    func parseQuestionLabel() -> (Int, String?) {
        guard let label = activeQuestionLabel, label.hasPrefix("Q"), label.count >= 2 else { return (0, nil) }
        let numAndLabel = label.dropFirst()
        var numStr = ""
        var partStr = ""
        for ch in numAndLabel {
            if ch.isNumber { numStr.append(ch) } else { partStr.append(ch) }
        }
        return (Int(numStr) ?? 0, partStr.isEmpty ? nil : partStr)
    }

    // MARK: - Page Mutations

    func addBlankPageAtEnd(drawingManager: CanvasDrawingManager) {
        let insertIndex = pdfDocument.pageCount
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        addedPageIndices.append(insertIndex)
        containerView?.skipDrawingSaveOnRebuild = true
        pageVersion += 1
    }

    func addBlankPageAfterCurrent(drawingManager: CanvasDrawingManager) {
        let insertIndex = currentPageIndex + 1
        let blank = createBlankPage()
        pdfDocument.insert(blank, at: insertIndex)
        drawingManager.shiftDrawingsForInsert(at: insertIndex)
        // Shift any tracked added indices that are >= insertIndex
        addedPageIndices = addedPageIndices.map { $0 >= insertIndex ? $0 + 1 : $0 }
        addedPageIndices.append(insertIndex)
        containerView?.skipDrawingSaveOnRebuild = true
        pageVersion += 1
    }

    func clearAllStrokes() {
        guard let container = containerView else { return }
        let savedCallback = drawingManager.onDrawingChanged
        drawingManager.onDrawingChanged = nil
        for i in 0..<container.canvasViews.count {
            drawingManager.setDrawing(PKDrawing(), for: i)
            container.canvasViews[i].drawing = PKDrawing()
        }
        drawingManager.onDrawingChanged = savedCallback
        drawingManager.onDrawingChanged?()

        // Reset all tutor state
        clearShapeStrokes()
        currentTutorStepIndex = 0
        tutorEvalService.reset()
        savedTutorProgress = nil

        saveCanvasState()
    }

    func deleteCurrentPage(drawingManager: CanvasDrawingManager) {
        guard pdfDocument.pageCount > 1 else { return }
        let removeIndex = currentPageIndex
        pdfDocument.removePage(at: removeIndex)
        drawingManager.shiftDrawingsForDelete(at: removeIndex)
        // Remove the deleted index and shift down indices above it
        addedPageIndices.removeAll { $0 == removeIndex }
        addedPageIndices = addedPageIndices.map { $0 > removeIndex ? $0 - 1 : $0 }
        if currentPageIndex >= pdfDocument.pageCount {
            currentPageIndex = pdfDocument.pageCount - 1
        }
        containerView?.skipDrawingSaveOnRebuild = true
        pageVersion += 1
    }

    // MARK: - Persistence

    func saveCanvasState() {
        let drawingData: [String: Data] = drawingManager.drawings.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value.dataRepresentation()
        }

        print("[CanvasVM] Saving: \(drawingData.count) drawings, \(drawingData.values.map(\.count).reduce(0,+)) bytes total")

        // Tutor state + active question live in Supabase — not persisted locally.
        let state = CanvasDocumentData(
            documentId: document.id,
            originalPageCount: originalPageCount,
            addedPageIndices: addedPageIndices,
            overlaySettings: overlaySettings,
            currentPageIndex: currentPageIndex,
            drawingDataByPage: drawingData,
            tutorProgress: nil,
            activeQuestionLabel: nil
        )

        Task.detached {
            do {
                try CanvasStorageService.save(state)
                print("[CanvasVM] Save OK")
            } catch {
                print("[CanvasVM] Save failed: \(error)")
            }
        }
    }

    private func createBlankPage() -> PDFPage {
        let size: CGSize
        if let firstPage = pdfDocument.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            size = CGSize(width: bounds.width, height: bounds.height)
        } else {
            size = CGSize(width: 612, height: 792)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        guard let cgImage = image.cgImage else {
            return PDFPage()
        }

        guard let page = PDFPage(image: UIImage(cgImage: cgImage)) else {
            return PDFPage()
        }
        page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        return page
    }

    func addColor(_ color: UIColor) {
        switch selectedTool {
        case .highlighter:
            customHighlighterColors.append(color)
            highlighterColor = color
        case .shapes:
            customShapesColors.append(color)
            shapesColor = color
        default:
            customColors.append(color)
            penColor = color
        }
        showAddColor = false
    }

    var hasActiveOverlay: Bool {
        overlaySettings.type != .none
    }

}
