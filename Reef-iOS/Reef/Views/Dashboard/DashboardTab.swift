import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case documents
    case courses
    case analytics
    case myReef
    case library
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: "Documents"
        case .courses: "Courses"
        case .analytics: "Analytics"
        case .myReef: "My Reef"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .documents: "doc.text"
        case .courses: "graduationcap"
        case .analytics: "chart.bar"
        case .myReef: "heart"
        case .library: "books.vertical"
        case .settings: "gearshape"
        }
    }

    static var mainTabs: [DashboardTab] {
        [.documents, .courses, .analytics, .myReef, .library]
    }
}
