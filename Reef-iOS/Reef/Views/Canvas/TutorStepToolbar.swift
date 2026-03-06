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

    // MARK: - 3D Progress Bar

    /// Fill color shifts from white → teal → green as progress approaches 100%.
    private func fillColor(for progress: Double) -> Color {
        if progress < 0.5 {
            return .white.opacity(0.85)
        } else if progress < 0.8 {
            return Color(hex: 0xA8D5D5)  // ReefColors.accent (light teal)
        } else {
            return Color(hex: 0x81C784)  // green (same as completed icon)
        }
    }

    private func progressBar(progress: Double) -> some View {
        let percent = Int(progress * 100)
        let barHeight: CGFloat = 14
        let cornerRadius: CGFloat = 5
        let shadowOffset: CGFloat = 2

        return HStack(alignment: .center, spacing: 7) {
            // Bar with 3D shadow
            ZStack(alignment: .leading) {
                // Shadow layer
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.3))
                    .offset(x: shadowOffset, y: shadowOffset)

                // Track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.2))

                // Fill
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fillColor(for: progress))
                        .frame(width: max(barHeight, geo.size.width * progress))
                }

                // Top highlight for 3D effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: barHeight / 2)

                // Border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            }
            .frame(width: 100, height: barHeight)
            .animation(.easeInOut(duration: 0.4), value: progress)

            // Percentage label
            HStack(spacing: 0) {
                Text("\(percent)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .baselineOffset(1)
            }
            .foregroundColor(.white.opacity(0.75))
            .fixedSize()
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(for status: StepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        case .mistake:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: 0xE57373))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
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
