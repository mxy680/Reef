import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    var selectedTab: DashboardTab? = .documents
    var selectedCourseId: String?
    var sidebarOpen = true
    var showProfileMenu = false

    // Stub — courses will be wired to a repository later
    var courses: [String] = []

    var contentTitle: String {
        if let tab = selectedTab {
            return tab.label
        }
        if let courseId = selectedCourseId {
            return courseId // Replace with course name lookup later
        }
        return "Dashboard"
    }

    func selectTab(_ tab: DashboardTab) {
        selectedTab = tab
        selectedCourseId = nil
    }

    func selectCourse(_ id: String) {
        selectedCourseId = id
        selectedTab = nil
    }

    func toggleSidebar() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            sidebarOpen.toggle()
        }
    }

    func toggleProfileMenu() {
        withAnimation(.spring(duration: 0.2)) {
            showProfileMenu.toggle()
        }
    }

    func dismissProfileMenu() {
        withAnimation(.spring(duration: 0.2)) {
            showProfileMenu = false
        }
    }
}
