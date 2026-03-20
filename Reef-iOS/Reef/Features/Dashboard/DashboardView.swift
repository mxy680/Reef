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
        }
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
                    canvasVM = CanvasViewModel(document: doc)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        canvasDocument = doc
                    }
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
                    canvasVM = CanvasViewModel(document: doc)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        canvasDocument = doc
                    }
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
}
