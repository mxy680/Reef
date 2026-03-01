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
        case .documents: "doc.text"
        case .analytics: "chart.bar"
        case .myReef: "heart"
        case .library: "books.vertical"
        case .tutors: "person.2"
        case .settings: "gearshape"
        }
    }

    static var mainTabs: [DashboardTab] {
        [.documents, .analytics, .myReef, .tutors, .library]
    }
}
