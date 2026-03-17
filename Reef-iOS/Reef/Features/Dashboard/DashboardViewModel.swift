import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    var selectedTab: DashboardTab? = .documents
    var selectedCourseId: String?
    var sidebarOpen = true
    var showProfileMenu = false
    var showNotifications = false
    var showSearch = false
    var showHelp = false

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

    func dismissAllDropdowns() {
        showProfileMenu = false
        showNotifications = false
        showSearch = false
        showHelp = false
    }

    enum Dropdown {
        case search, help, notifications, profile
    }

    /// Close all other dropdowns, then toggle the target one.
    func toggleDropdown(_ dropdown: Dropdown) {
        let wasOpen: Bool
        switch dropdown {
        case .search: wasOpen = showSearch
        case .help: wasOpen = showHelp
        case .notifications: wasOpen = showNotifications
        case .profile: wasOpen = showProfileMenu
        }
        dismissAllDropdowns()
        switch dropdown {
        case .search: showSearch = !wasOpen
        case .help: showHelp = !wasOpen
        case .notifications: showNotifications = !wasOpen
        case .profile: showProfileMenu = !wasOpen
        }
    }
}
