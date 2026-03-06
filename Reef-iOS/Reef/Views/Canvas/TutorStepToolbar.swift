//
//  TutorStepToolbar.swift
//  Reef
//
//  Row 3 of the canvas toolbar — only visible when Tutor Mode is ON.
//  Lighter teal: barColor + white 12% overlay (vs black 18% for Row 1).
//

import SwiftUI

struct TutorStepToolbar: View {
    let questionIndex: Int
    @State private var stepIndex = 0

    private var steps: [TutorStep] {
        MockTutorSteps.steps(for: questionIndex)
    }

    private var currentStep: TutorStep {
        steps[stepIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Step navigation
                HStack(spacing: 0) {
                    stepNavButton(icon: "chevron.left", enabled: stepIndex > 0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            stepIndex -= 1
                        }
                    }
                    stepNavButton(icon: "chevron.right", enabled: stepIndex < steps.count - 1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            stepIndex += 1
                        }
                    }
                }

                makeDivider()

                // Step counter + instruction
                HStack(spacing: 10) {
                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()

                    Text(currentStep.instruction)
                        .font(.epilogue(13, weight: .medium))
                        .tracking(-0.04 * 13)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)

                makeDivider()

                // Hint + Reveal
                HStack(spacing: 0) {
                    toolbarButton(icon: "lightbulb.fill") {
                        print("💡 Hint: \(currentStep.hint)")
                    }
                    toolbarButton(icon: "eye.fill") {
                        print("👁 Reveal answer tapped for step \(stepIndex + 1)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                ZStack {
                    CanvasToolbar.barColor
                    Color.white.opacity(0.12)
                }
            )

            // Bottom separator
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .onChange(of: questionIndex) { _, _ in
            stepIndex = 0
        }
    }

    // MARK: - Step Nav Button

    private func stepNavButton(
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { if enabled { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(enabled ? .white.opacity(0.9) : .white.opacity(0.3))
                .frame(width: 36, height: 36, alignment: .center)
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar Button

    private func toolbarButton(
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 36, height: 36, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }

    // MARK: - Divider

    private func makeDivider() -> some View {
        Text("|")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.5))
            .frame(width: 20)
    }
}
