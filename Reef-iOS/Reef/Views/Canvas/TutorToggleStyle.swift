//
//  TutorToggleStyle.swift
//  Reef
//

import SwiftUI

// MARK: - Tutor Toggle Style

/// Custom toggle with 3D neobrutalist styling on the teal toolbar.
struct TutorToggleStyle: ToggleStyle {
    private static let barColor = Color(hex: 0x4E8A97)

    func makeBody(configuration: Configuration) -> some View {
        let trackWidth: CGFloat = 36
        let trackHeight: CGFloat = 20
        let knobSize: CGFloat = 16
        let knobPadding: CGFloat = 2

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn
                          ? Self.barColor
                          : Color.black.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color.black.opacity(0.5),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: trackWidth, height: trackHeight)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                            .offset(x: 1.5, y: 1.5)
                    )

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
        }
        .buttonStyle(.plain)
    }
}
