//
//  StatsRowView.swift
//  Reef
//
//  Stats row component showing study streak, time, problems, and AI feedback.
//

import SwiftUI

struct StatsRowView: View {
    @ObservedObject var statsService: StudyStatsService
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 20) {
            StatCardView(
                icon: "flame.fill",
                value: "\(statsService.studyStreak)",
                label: "day streak",
                colorScheme: colorScheme
            )

            StatCardView(
                icon: "clock.fill",
                value: statsService.formattedStudyTime,
                label: "this week",
                colorScheme: colorScheme
            )

            StatCardView(
                icon: "checkmark.circle.fill",
                value: "\(statsService.problemsSolved)",
                label: "problems",
                colorScheme: colorScheme
            )

            StatCardView(
                icon: "sparkles",
                value: "\(statsService.aiFeedbackCount)",
                label: "AI feedback",
                colorScheme: colorScheme
            )
        }
    }
}

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.deepTeal)

            Text(value)
                .font(.quicksand(28, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            Text(label)
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.06 : 0.03), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    StatsRowView(statsService: StudyStatsService.shared, colorScheme: .light)
        .padding()
        .background(Color.adaptiveBackground(for: .light))
}
