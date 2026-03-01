import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case documents
    case courses
    case analytics
    case myReef
    case library
    case help
    case billing
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: "Documents"
        case .courses: "Courses"
        case .analytics: "Analytics"
        case .myReef: "My Reef"
        case .library: "Library"
        case .help: "Help"
        case .billing: "Billing"
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
        case .help: "questionmark.circle"
        case .billing: "creditcard"
        case .settings: "gearshape"
        }
    }

    var isMain: Bool {
        switch self {
        case .documents, .courses, .analytics, .myReef, .library: true
        case .help, .billing, .settings: false
        }
    }

    static var mainTabs: [DashboardTab] {
        allCases.filter(\.isMain)
    }

    static var bottomTabs: [DashboardTab] {
        allCases.filter { !$0.isMain }
    }
}
