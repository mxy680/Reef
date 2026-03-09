//
//  TutorStepToolbar.swift
//  Reef
//
//  Row 3 of the canvas toolbar — only visible when Tutor Mode is ON.
//  Lighter teal: barColor + white 12% overlay (vs black 18% for Row 1).
//

import SwiftUI

struct TutorStepToolbar: View {
    @Environment(ThemeManager.self) private var theme
    let questionIndex: Int
    let answerKey: QuestionAnswer?
    @State private var stepIndex = 0
    @State private var hintActive = false
    @State private var revealActive = false
    @State private var pulseOpacity: Double = 1.0

    private var steps: [TutorStep] {
        guard let answerKey else { return [] }
        return TutorStepConverter.steps(from: answerKey)
    }

    private var currentStep: TutorStep? {
        guard !steps.isEmpty else { return nil }
        return steps[min(stepIndex, steps.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let step = currentStep {
                stepContent(step: step)
            } else {
                loadingContent
            }

            // Bottom separator
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .onChange(of: questionIndex) { _, _ in
            stepIndex = 0
            hintActive = false
            revealActive = false
        }
    }

    // MARK: - Content Views

    private func stepContent(step: TutorStep) -> some View {
        HStack(spacing: 0) {
            // Status indicator + step counter
            HStack(spacing: 6) {
                statusIcon(for: step.status)

                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize()
            }

            makeDivider()

            // Instruction text
            Text(step.instruction)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .id(stepIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            makeDivider()

            // Hint + Reveal
            HStack(spacing: 0) {
                toolbarToggle(icon: "lightbulb.fill", isActive: $hintActive) {
                    hintActive.toggle()
                    if hintActive { revealActive = false }
                    print("[Tutor] Hint: \(step.hint)")
                }
                toolbarToggle(icon: "eye.fill", isActive: $revealActive) {
                    revealActive.toggle()
                    if revealActive { hintActive = false }
                    print("[Tutor] Work: \(step.work)")
                }
            }

            makeDivider()

            // Progress bar
            progressBar(progress: step.progress)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(toolbarBackground)
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
    }

    private var loadingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white.opacity(0.7))
                .scaleEffect(0.7)
            Text("Loading answer key...")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(toolbarBackground)
    }

    private var toolbarBackground: some View {
        ZStack {
            theme.isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasToolbar.barColor
            Color.white.opacity(theme.isDarkMode ? 0.06 : 0.12)
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
        let isPending = currentStep?.status == .pending

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

                // Fill with pulse when pending
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fillColor(for: progress))
                        .frame(width: max(barHeight, geo.size.width * progress))
                        .opacity(isPending ? pulseOpacity : 1.0)
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
            .onAppear { startPulse() }

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

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 0.5
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

    // MARK: - Toolbar Toggle Button

    private func toolbarToggle(
        icon: String,
        isActive: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isActive.wrappedValue ? .white : .white.opacity(0.9))
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    isActive.wrappedValue
                        ? Color.white.opacity(0.25)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(.easeInOut(duration: 0.15), value: isActive.wrappedValue)
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
