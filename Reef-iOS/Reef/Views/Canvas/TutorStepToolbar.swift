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

    /// Cold/hot gradient stops for the progress bar
    private static let coldColor = Color(hex: 0x5B9EAD)
    private static let warmColor = Color(hex: 0xE8A87C)
    private static let hotColor = Color(hex: 0xD4605A)

    private var steps: [TutorStep] {
        MockTutorSteps.steps(for: questionIndex)
    }

    private var currentStep: TutorStep {
        steps[stepIndex]
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

                makeDivider()

                // Hot/cold progress bar
                progressBar(progress: currentStep.progress)
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

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.15))

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Self.coldColor, Self.warmColor, Self.hotColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.height, geo.size.width * progress))
            }
        }
        .frame(width: 80, height: 8)
        .animation(.easeInOut(duration: 0.4), value: progress)
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
