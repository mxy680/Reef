import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab: DashboardTab? = .documents
    @State private var selectedCourseId: String?
    @State private var courses: [Course] = []
    @State private var sidebarOpen = true

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
        switch selectedTab {
        case .documents:
            DocumentsContentView()
        case .tutors:
            TutorsContentView()
        default:
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
