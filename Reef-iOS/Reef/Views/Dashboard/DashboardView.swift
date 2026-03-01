import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab: DashboardTab? = .documents
    @State private var selectedCourseId: String?
    @State private var courses: [Course] = []
    @State private var sidebarOpen = true
    @State private var courseToDelete: Course?
    @State private var courseToEdit: Course?

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
                .padding(.leading, 12)
                .padding(.vertical, 12)

                // Main column
                VStack(spacing: 0) {
                    DashboardHeader(title: contentTitle)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)

                    contentArea
                        .padding(12)
                }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: sidebarOpen)
        .task { await fetchCourses() }
        // Full-screen modal overlays
        .overlay {
            if courseToDelete != nil || courseToEdit != nil {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2)) {
                                courseToDelete = nil
                                courseToEdit = nil
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
                        .contentShape(Rectangle())
                        .onTapGesture { }
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
                        .contentShape(Rectangle())
                        .onTapGesture { }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(duration: 0.2), value: courseToDelete?.id)
        .animation(.spring(duration: 0.2), value: courseToEdit?.id)
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
                DocumentsContentView()
            default:
                comingSoonPlaceholder
            }
        } else if let courseId = selectedCourseId,
                  let course = courses.first(where: { $0.id == courseId }) {
            CourseDetailView(
                courseId: courseId,
                course: course,
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

    private var comingSoonPlaceholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(contentTitle)
                .font(.epilogue(28, weight: .black))
                .tracking(-0.04 * 28)
                .foregroundStyle(ReefColors.black)

            Text("Coming soon")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.04 * 15)
                .foregroundStyle(ReefColors.gray600)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .dashboardCard()
    }
}

// MARK: - Dotted Background

struct DottedBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            let dotSize: CGFloat = 1.5

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(ReefColors.gray100)
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .background(ReefColors.white)
    }
}
