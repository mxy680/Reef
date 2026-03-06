import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case documents
    case analytics
    case myReef
    case library
    case tutors
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: "Documents"
        case .analytics: "Analytics"
        case .myReef: "My Reef"
        case .library: "Library"
        case .tutors: "Tutors"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .documents: "tab.documents"
        case .analytics: "tab.analytics"
        case .myReef: "tab.reef"
        case .library: "tab.library"
        case .tutors: "tab.tutors"
        case .settings: "gearshape"
        }
    }

    /// Whether this tab uses a custom asset image (vs SF Symbol)
    var isCustomIcon: Bool {
        switch self {
        case .settings: false
        default: true
        }
    }

    static var mainTabs: [DashboardTab] {
        [.documents, .analytics, .myReef, .tutors, .library]
    }
}
