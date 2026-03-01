//
//  HomeView.swift
//  Reef
//
//  Placeholder post-auth view
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ZStack {
            Color.adaptiveBackground(for: effectiveColorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Welcome to Reef")
                    .font(.quicksandTitle)
                    .foregroundColor(.adaptiveText(for: effectiveColorScheme))

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.quicksandBody)
                        .foregroundColor(.adaptiveSecondaryText(for: effectiveColorScheme))
                }

                Button {
                    authManager.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.quicksandHeadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.deepCoral)
                        .cornerRadius(12)
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
    }
}

#Preview {
    HomeView(authManager: AuthenticationManager())
}
