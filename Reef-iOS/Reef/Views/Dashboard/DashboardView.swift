import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab: DashboardTab? = .documents
    @State private var selectedCourseId: String?
    @State private var courses: [Course] = []
    @State private var sidebarOpen = true
    @State private var courseToDelete: Course?
    @State private var courseToEdit: Course?
    @State private var documentsVM = DocumentsViewModel()
    @State private var tutorsVM = TutorsViewModel()
    var onOpenCanvas: (Document) -> Void

    private let metrics = LayoutMetrics(
        screenHeight: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    )

    var body: some View {
        ZStack {
            // Dotted grid background
            DottedBackground()
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                // Sidebar
                DashboardSidebar(
                    selectedTab: $selectedTab,
                    selectedCourseId: $selectedCourseId,
                    courses: $courses,
                    isOpen: $sidebarOpen
                )
                // Main column
                VStack(spacing: 0) {
                    DashboardHeader(
                        title: contentTitle,
                        selectedTab: $selectedTab,
                        selectedCourseId: $selectedCourseId
                    )
                        .padding(.horizontal, 12)

                    contentArea
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                }
            }

            // Modal backdrop + content in the same ZStack so the TextField
            // participates in the main responder chain (keyboard works).
            if courseToDelete != nil || courseToEdit != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            courseToDelete = nil
                            courseToEdit = nil
                        }
                    }
            }

            if let course = courseToDelete {
                DeleteCourseSheet(
                    course: course,
                    onConfirm: {
                        Task {
                            do {
                                try await CourseService.shared.deleteCourse(course.id)
                                courseToDelete = nil
                                selectedTab = .documents
                                selectedCourseId = nil
                                await fetchCourses()
                            } catch {
                                print("Failed to delete course: \(error)")
                            }
                        }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            courseToDelete = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if let course = courseToEdit {
                EditCourseSheet(
                    course: course,
                    onConfirm: { name, emoji, color in
                        Task {
                            do {
                                try await CourseService.shared.updateCourse(course.id, name: name, emoji: emoji, color: color)
                                withAnimation(.spring(duration: 0.2)) {
                                    courseToEdit = nil
                                }
                                await fetchCourses()
                            } catch {
                                print("Failed to update course: \(error)")
                            }
                        }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            courseToEdit = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            // Tutor detail popup
            if tutorsVM.selectedTutor != nil || tutorsVM.showQuiz {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            tutorsVM.selectedTutor = nil
                            tutorsVM.showQuiz = false
                        }
                    }
            }

            if let tutor = tutorsVM.selectedTutor {
                TutorDetailPopup(
                    tutor: tutor,
                    isSpeaking: tutorsVM.speakingTutorId == tutor.id,
                    isActive: tutorsVM.activeTutorId == tutor.id,
                    onVoicePreview: { tutorsVM.toggleVoicePreview(for: tutor) },
                    onSelect: { tutorsVM.selectTutor(tutor) },
                    onClose: {
                        withAnimation(.spring(duration: 0.3)) {
                            tutorsVM.selectedTutor = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if tutorsVM.showQuiz {
                TutorQuizPopup(
                    tutors: tutorsVM.tutors,
                    onSelectTutor: { tutor in
                        tutorsVM.selectTutor(tutor)
                        withAnimation(.spring(duration: 0.3)) {
                            tutorsVM.showQuiz = false
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(duration: 0.3)) {
                            tutorsVM.showQuiz = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Document modals
            if documentsVM.pendingUploadURL != nil || documentsVM.deleteTarget != nil
                || documentsVM.renameTarget != nil || documentsVM.moveToCourseTarget != nil
                || documentsVM.detailsTarget != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.pendingUploadURL = nil
                            documentsVM.deleteTarget = nil
                            documentsVM.renameTarget = nil
                            documentsVM.moveToCourseTarget = nil
                            documentsVM.detailsTarget = nil
                        }
                    }
            }

            if let doc = documentsVM.deleteTarget {
                DeleteConfirmSheet(
                    document: doc,
                    onConfirm: { Task { await documentsVM.deleteDocument() } },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.deleteTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if let doc = documentsVM.renameTarget {
                RenameSheet(
                    document: doc,
                    onConfirm: { name in Task { await documentsVM.renameDocument(newFilename: name) } },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.renameTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if let doc = documentsVM.moveToCourseTarget {
                MoveToCourseSheet(
                    document: doc,
                    onConfirm: { courseId in Task { await documentsVM.moveDocumentToCourse(courseId: courseId) } },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.moveToCourseTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if let doc = documentsVM.detailsTarget {
                DetailsSheet(
                    document: doc,
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.detailsTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if let url = documentsVM.pendingUploadURL {
                DocumentUploadSheet(
                    filename: url.deletingPathExtension().lastPathComponent,
                    onConfirm: { courseId, reconstruct in
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.performUploadWithOptions(courseId: courseId, reconstruct: reconstruct)
                        }
                    },
                    onClose: {
                        withAnimation(.spring(duration: 0.2)) {
                            documentsVM.pendingUploadURL = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

        }
        .environment(\.layoutMetrics, metrics)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: sidebarOpen)
        .animation(.spring(duration: 0.2), value: courseToDelete?.id)
        .animation(.spring(duration: 0.2), value: courseToEdit?.id)
        .animation(.spring(duration: 0.3), value: tutorsVM.selectedTutor?.id)
        .animation(.spring(duration: 0.3), value: tutorsVM.showQuiz)
        .animation(.spring(duration: 0.2), value: documentsVM.deleteTarget?.id)
        .animation(.spring(duration: 0.2), value: documentsVM.renameTarget?.id)
        .animation(.spring(duration: 0.2), value: documentsVM.moveToCourseTarget?.id)
        .animation(.spring(duration: 0.2), value: documentsVM.detailsTarget?.id)
        .animation(.spring(duration: 0.2), value: documentsVM.pendingUploadURL)
        .task { await fetchCourses() }
    }

    private func fetchCourses() async {
        do {
            courses = try await CourseService.shared.listCourses()
        } catch {
            print("Failed to fetch courses: \(error)")
        }
    }

    private var contentTitle: String {
        if let tab = selectedTab {
            return tab.label
        }
        if let courseId = selectedCourseId,
           let course = courses.first(where: { $0.id == courseId }) {
            return course.name
        }
        return "Dashboard"
    }

    @ViewBuilder
    private var contentArea: some View {
        if let tab = selectedTab {
            switch tab {
            case .documents:
                DocumentsContentView(viewModel: documentsVM, onOpenCanvas: onOpenCanvas)
            case .tutors:
                TutorsContentView(viewModel: tutorsVM)
            case .myReef:
                MyReefComingSoonView()
            case .library:
                LibraryComingSoonView()
            case .analytics:
                AnalyticsView()
            case .settings:
                SettingsView()
            }
        } else if let courseId = selectedCourseId,
                  let course = courses.first(where: { $0.id == courseId }) {
            CourseDetailView(
                courseId: courseId,
                course: course,
                onOpenCanvas: onOpenCanvas,
                onCourseDeleted: {
                    selectedTab = .documents
                    selectedCourseId = nil
                    Task { await fetchCourses() }
                },
                onCourseUpdated: {
                    Task { await fetchCourses() }
                },
                onEditTapped: { course in
                    withAnimation(.spring(duration: 0.2)) {
                        courseToEdit = course
                    }
                },
                onDeleteTapped: { course in
                    withAnimation(.spring(duration: 0.2)) {
                        courseToDelete = course
                    }
                }
            )
        } else {
            comingSoonPlaceholder
        }
    }

    @Environment(ThemeManager.self) private var theme

    private var comingSoonPlaceholder: some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 16) {
            Text(contentTitle)
                .font(.epilogue(28, weight: .black))
                .tracking(-0.04 * 28)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Text("Coming soon")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
    }
}
