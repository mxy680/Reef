//
//  TutorStepToolbar.swift
//  Reef
//
//  Row 3 of the canvas toolbar — only visible when Tutor Mode is ON.
//  Background shifts from cool teal (cold) to warm amber (hot) based on step progress.
//

import SwiftUI

struct TutorStepToolbar: View {
    let questionIndex: Int
    @State private var stepIndex = 0

    /// Cold = lighter teal (barColor + white overlay)
    private static let coldColor = Color(hex: 0x5FA8B3)
    /// Hot = warm amber
    private static let hotColor = Color(hex: 0xD4915E)

    private var steps: [TutorStep] {
        MockTutorSteps.steps(for: questionIndex)
    }

    private var currentStep: TutorStep {
        steps[stepIndex]
    }

    private var barBackground: Color {
        Self.coldColor.mix(with: Self.hotColor, by: currentStep.progress)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Status indicator + step counter
                HStack(spacing: 6) {
                    statusIcon(for: currentStep.status)

                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                }

                makeDivider()

                // Instruction text
                Text(currentStep.instruction)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)

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
            .background(barBackground)
            .animation(.easeInOut(duration: 0.4), value: currentStep.progress)

            // Bottom separator
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .onChange(of: questionIndex) { _, _ in
            stepIndex = 0
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(for status: StepStatus) -> some View {
        switch status {
        case .working:
            Image(systemName: "circle.dotted")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        case .mistake:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: 0xE57373))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: 0x81C784))
        }
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
