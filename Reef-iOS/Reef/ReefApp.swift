//
//  ReefApp.swift
//  Reef
//

import SwiftUI

@main
struct ReefApp: App {
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    ZStack {
                        Color.blushWhite.ignoresSafeArea()
                        ProgressView()
                    }
                } else if authManager.isAuthenticated {
                    HomeView(authManager: authManager)
                } else {
                    PreAuthView(authManager: authManager)
                }
            }
        }
    }
}
