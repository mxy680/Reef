import SwiftUI

struct DashboardView: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics
    @State private var viewModel = DashboardViewModel()
    @State private var documentsVM = DocumentsViewModel()
    @State private var coursesVM = CoursesViewModel()
    @State private var canvasDocument: Document?
    @State private var canvasVM: CanvasViewModel?
    @State private var pendingDocument: Document?  // Shows tutor mode dialog before opening
    @State private var dontAskAgain = false
    @AppStorage("tutorModePreference") private var savedPreference: String = ""  // "", "voice", "text", "none"

    var body: some View {
        ZStack {
            DottedBackground()
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                DashboardSidebar(viewModel: viewModel, coursesVM: coursesVM)

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: metrics.headerHeight + metrics.headerGap)

                        contentArea
                            .padding(.horizontal, metrics.dashboardHPadding)
                    }
                    // Dismiss backdrop covers content + sidebar but NOT header
                    .overlay {
                        if anyDropdownOpen {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.dismissAllDropdowns() }
                        }
                    }

                    DashboardHeader(viewModel: viewModel)
                        .padding(.horizontal, metrics.dashboardHPadding)
                }
            }
            .padding(.horizontal, metrics.dashboardHPadding)
            .padding(.top, metrics.dashboardTopPadding)

            // MARK: - Document Modal Overlays

            if documentsVM.deleteTarget != nil || documentsVM.renameTarget != nil
                || documentsVM.detailsTarget != nil || documentsVM.moveToCourseTarget != nil
                || documentsVM.pendingUploadURL != nil
                || coursesVM.addCourseTarget || coursesVM.editCourseTarget != nil
                || coursesVM.deleteCourseTarget != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.deleteTarget = nil
                            documentsVM.renameTarget = nil
                            documentsVM.detailsTarget = nil
                            documentsVM.moveToCourseTarget = nil
                            documentsVM.pendingUploadURL = nil
                            coursesVM.addCourseTarget = false
                            coursesVM.editCourseTarget = nil
                            coursesVM.deleteCourseTarget = nil
                        }
                    }
            }

            if let doc = documentsVM.deleteTarget {
                DeleteConfirmPopup(document: doc) {
                    Task { await documentsVM.deleteDocument() }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.deleteTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.deleteTarget != nil)
            }

            if let doc = documentsVM.renameTarget {
                RenamePopup(document: doc) { newFilename in
                    Task { await documentsVM.renameDocument(newFilename: newFilename) }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.renameTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.renameTarget != nil)
            }

            if let doc = documentsVM.detailsTarget {
                DetailsPopup(document: doc) {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.detailsTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.detailsTarget != nil)
            }

            if let doc = documentsVM.moveToCourseTarget {
                MoveToCoursePopup(document: doc) { courseId in
                    Task { await documentsVM.moveDocumentToCourse(courseId: courseId) }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.moveToCourseTarget = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.moveToCourseTarget != nil)
            }

            if let url = documentsVM.pendingUploadURL {
                DocumentUploadPopup(filename: url.lastPathComponent) { courseId, reconstruct in
                    documentsVM.performUploadWithOptions(courseId: courseId, reconstruct: reconstruct)
                    withAnimation(.spring(duration: 0.2)) { }
                } onClose: {
                    withAnimation(.spring(duration: 0.2)) { documentsVM.pendingUploadURL = nil }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: documentsVM.pendingUploadURL != nil)
            }
            // MARK: - Course Modal Overlays

            if coursesVM.addCourseTarget {
                AddCoursePopup(
                    onConfirm: { name, icon, color in
                        withAnimation(.spring(duration: 0.2)) { coursesVM.addCourseTarget = false }
                        Task {
                            if let newCourse = await coursesVM.createCourse(name: name, emoji: icon, color: color) {
                                viewModel.selectedCourseName = newCourse.name
                                viewModel.selectCourse(newCourse.id)
                            }
                        }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) { coursesVM.addCourseTarget = false }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: coursesVM.addCourseTarget)
            }

            if let course = coursesVM.editCourseTarget {
                EditCoursePopup(
                    course: course,
                    onConfirm: { name, icon, color in
                        withAnimation(.spring(duration: 0.2)) { coursesVM.editCourseTarget = nil }
                        Task { await coursesVM.updateCourse(id: course.id, name: name, emoji: icon, color: color) }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) { coursesVM.editCourseTarget = nil }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: coursesVM.editCourseTarget != nil)
            }

            if let course = coursesVM.deleteCourseTarget {
                DeleteCoursePopup(
                    course: course,
                    onConfirm: {
                        withAnimation(.spring(duration: 0.2)) { coursesVM.deleteCourseTarget = nil }
                        Task {
                            await coursesVM.deleteCourse(course.id)
                            viewModel.selectTab(.documents)
                        }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) { coursesVM.deleteCourseTarget = nil }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(.spring(duration: 0.2), value: coursesVM.deleteCourseTarget != nil)
            }

            // MARK: - Canvas Fullscreen Overlay

            if canvasDocument != nil, let vm = canvasVM {
                if vm.isLoadingPDF {
                    // Loading overlay while PDF downloads
                    ZStack {
                        (Color(hex: 0xF8F0E6))
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(ReefColors.primary)
                                .scaleEffect(1.2)

                            Text("Loading document...")
                                .font(.epilogue(14, weight: .medium))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(ReefColors.gray500)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                } else {
                    CanvasView(
                        viewModel: vm,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                canvasDocument = nil
                            }
                            canvasVM = nil
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            // MARK: - Tutor Mode Dialog

            if pendingDocument != nil {
                tutorModeDialog
                    .zIndex(200)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pendingDocument?.id)
        .task { await coursesVM.fetchCourses() }
        .onChange(of: viewModel.selectedCourseId) { _, newId in
            viewModel.selectedCourseName = coursesVM.courses.first(where: { $0.id == newId })?.name
        }
        .animation(.easeInOut(duration: 0.3), value: canvasDocument?.id)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.sidebarOpen)
        .alert(
            "Error",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )
        ) {
            Button("OK") { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    private var anyDropdownOpen: Bool {
        viewModel.showProfileMenu || viewModel.showNotifications || viewModel.showSearch || viewModel.showHelp
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let tab = viewModel.selectedTab {
            switch tab {
            case .documents:
                DocumentsContentView(viewModel: documentsVM, onOpenCanvas: { doc in
                    openOrAskTutorMode(doc)
                })
            case .analytics:
                AnalyticsView()
            case .myReef:
                ComingSoonView(
                    icon: "water.waves",
                    title: "Your reef is growing",
                    subtitle: "Track your marine species collection as you master new topics."
                )
            case .tutors:
                ComingSoonView(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "Your crew is assembling",
                    subtitle: "AI tutors that guide you through every problem, coming soon."
                )
            case .library:
                ComingSoonView(
                    icon: "books.vertical",
                    title: "Deep waters ahead",
                    subtitle: "A shared library of study materials from your courses."
                )
            case .settings:
                SettingsView()
            default:
                tabPlaceholder(tab.label)
            }
        } else if let courseId = viewModel.selectedCourseId,
                  let course = coursesVM.courses.first(where: { $0.id == courseId }) {
            CourseContentView(
                course: course,
                onOpenCanvas: { doc in
                    openOrAskTutorMode(doc)
                },
                onEditTapped: {
                    coursesVM.editCourseTarget = course
                },
                onDeleteTapped: {
                    coursesVM.deleteCourseTarget = course
                }
            )
        } else {
            // Fallback — should not happen (selectedTab defaults to .documents)
            tabPlaceholder("Dashboard")
        }
    }

    private func tabPlaceholder(_ title: String) -> some View {
        let colors = theme.colors
        return VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            Text(title)
                .font(.epilogue(28, weight: .black))
                .tracking(-0.04 * 28)
                .foregroundStyle(colors.text)

            Text("Coming soon")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.contentPadding)
        .dashboardCard()
    }

    // MARK: - Tutor Mode Dialog

    private func openOrAskTutorMode(_ doc: Document) {
        switch savedPreference {
        case "voice": openDocument(doc, tutorMode: true, voiceEnabled: true)
        case "text":  openDocument(doc, tutorMode: true, voiceEnabled: false)
        case "none":  openDocument(doc, tutorMode: false, voiceEnabled: false)
        default:      pendingDocument = doc; dontAskAgain = false
        }
    }

    private func selectTutorMode(_ preference: String, doc: Document) {
        if dontAskAgain { savedPreference = preference }
        switch preference {
        case "voice": openDocument(doc, tutorMode: true, voiceEnabled: true)
        case "text":  openDocument(doc, tutorMode: true, voiceEnabled: false)
        default:      openDocument(doc, tutorMode: false, voiceEnabled: false)
        }
    }

    private func openDocument(_ doc: Document, tutorMode: Bool, voiceEnabled: Bool) {
        let vm = CanvasViewModel(document: doc)
        if !tutorMode {
            vm.deferTutorMode = true  // Prevents auto-enabling tutor
        }
        vm.tutorVoiceEnabled = voiceEnabled
        vm.tutorEvalService.voiceEnabled = voiceEnabled
        canvasVM = vm
        withAnimation(.easeInOut(duration: 0.3)) {
            canvasDocument = doc
            pendingDocument = nil
        }
    }

    private func tutorOption(
        icon: String, title: String, subtitle: String,
        colors: ReefThemeColors, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReefColors.primary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(14)
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 2))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colors.shadow)
                    .offset(x: 3, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var tutorModeDialog: some View {
        let colors = theme.colors

        return ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { pendingDocument = nil }
                }

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28))
                        .foregroundStyle(ReefColors.primary)

                    Text("How do you want to study?")
                        .font(.epilogue(20, weight: .black))
                        .tracking(-0.04 * 20)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 28)
                .padding(.bottom, 20)

                // Options
                VStack(spacing: 12) {
                    tutorOption(
                        icon: "speaker.wave.2.fill",
                        title: "Tutor with voice",
                        subtitle: "AI tutor speaks out loud as you work",
                        colors: colors
                    ) {
                        if let doc = pendingDocument { selectTutorMode("voice", doc: doc) }
                    }

                    tutorOption(
                        icon: "text.bubble",
                        title: "Tutor, text only",
                        subtitle: "AI tutor guides you through the chat sidebar",
                        colors: colors
                    ) {
                        if let doc = pendingDocument { selectTutorMode("text", doc: doc) }
                    }

                    tutorOption(
                        icon: "pencil.tip",
                        title: "Just the canvas",
                        subtitle: "No tutor — just draw and annotate",
                        colors: colors
                    ) {
                        if let doc = pendingDocument { selectTutorMode("none", doc: doc) }
                    }
                }
                .padding(.horizontal, 24)

                // Don't ask again checkbox
                Button {
                    dontAskAgain.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: dontAskAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundStyle(dontAskAgain ? ReefColors.primary : colors.textMuted)
                        Text("Don't ask me again")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(colors.textMuted)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 380)
            .background(colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colors.border, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 20).fill(colors.shadow).offset(x: 4, y: 4))
        }
    }
}
