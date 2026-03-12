//
//  TutorToggleStyle.swift
//  Reef
//

import SwiftUI

// MARK: - Tutor Toggle Style

/// Custom toggle with 3D neobrutalist styling matching the dashboard.
struct TutorToggleStyle: ToggleStyle {
    private static let barColor = Color(hex: 0x4E8A97)
    private static let borderColor = ReefColors.gray500

    @State private var isPressed = false

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
                          ? Color.white
                          : ReefColors.gray400)
                    .overlay(
                        Capsule()
                            .strokeBorder(ReefColors.gray500, lineWidth: 1.5)
                    )
                    .frame(width: trackWidth, height: trackHeight)
                    .background(
                        Capsule()
                            .fill(Self.borderColor)
                            .offset(x: isPressed ? 0 : 2, y: isPressed ? 0 : 2)
                    )
                    .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)

                Circle()
                    .fill(configuration.isOn ? Self.barColor : Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
                    .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.15)) { isPressed = false }
                }
        )
    }
}
