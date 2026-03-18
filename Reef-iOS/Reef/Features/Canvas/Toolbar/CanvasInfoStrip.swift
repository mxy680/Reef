import SwiftUI

// MARK: - Canvas Info Strip (Row 1)

struct CanvasInfoStrip: View {
    @Bindable var viewModel: CanvasViewModel

    let onClose: () -> Void

    /// The teal bar color, darkened by a black overlay.
    private var activeBarColor: Color {
        viewModel.isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasDrawingBar.barColor
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            // Home button
            Button(action: {
                viewModel.dismissAllPopovers()
                onClose()
            }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)

            if viewModel.tutorModeOn {
                tutorInfoContent
            } else {
                Spacer()
                Text(viewModel.document.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }

            // Right: progress + tutor toggle
            HStack(spacing: 0) {
                if viewModel.tutorModeOn, viewModel.currentTutorStep != nil {
                    HStack(spacing: 6) {
                        progressBar

                        HStack(spacing: 0) {
                            Text("\(Int(viewModel.tutorProgress * 100))")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("%")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .baselineOffset(1.5)
                        }

                        // Retry
                        Button(action: viewModel.resetTutorSteps) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 24)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Next step
                        Button(action: viewModel.advanceTutorStep) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 24)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Divider
                    Text("|")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 16)
                }

                // Tutor toggle
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Toggle("", isOn: $viewModel.tutorModeOn)
                        .toggleStyle(CanvasTutorToggleStyle())
                        .labelsHidden()
                }
            }
            .padding(.trailing, 10)
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            ZStack {
                activeBarColor
                Color.black.opacity(viewModel.isDarkMode ? 0.3 : 0.18)
            }
        )
    }

    // MARK: - Tutor Info Content

    private var tutorInfoContent: some View {
        HStack(spacing: 0) {
            makeDivider()

            HStack(spacing: 6) {
                // Status dot
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                    )

                Text(MockCanvasData.questionLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Text("Step \(viewModel.currentTutorStepIndex + 1)/\(viewModel.tutorStepCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            makeDivider()

            // Instruction
            if let step = viewModel.currentTutorStep {
                Text(step.instruction)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }
        }
    }

    // MARK: - Progress Bar

    @State private var pulseOpacity: Double = 1.0

    private var progressBar: some View {
        let progress = viewModel.tutorProgress
        let barHeight: CGFloat = 12
        let cornerRadius: CGFloat = 4
        let shadowOffset: CGFloat = 1.5

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .offset(x: shadowOffset, y: shadowOffset)

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.2))

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(progressFillColor(for: progress))
                    .frame(width: max(barHeight, geo.size.width * progress))
                    .opacity(pulseOpacity)
            }

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: barHeight / 2)

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .frame(width: 80, height: barHeight)
        .animation(.easeInOut(duration: 0.4), value: progress)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.5
            }
        }
    }

    private func progressFillColor(for progress: Double) -> Color {
        if progress < 0.5 {
            return .white.opacity(0.85)
        } else if progress < 0.8 {
            return Color(hex: 0xA8D5D5)
        } else {
            return Color(hex: 0x81C784)
        }
    }

    private func makeDivider() -> some View {
        Text("|")
            .font(.system(size: 20, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.4))
            .frame(width: 16)
    }
}

// MARK: - Tutor Toggle Style

struct CanvasTutorToggleStyle: ToggleStyle {
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
                          ? Color.white.opacity(0.35)
                          : Color.black.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color.white.opacity(0.25),
                                lineWidth: 0.5
                            )
                    )
                    .frame(width: trackWidth, height: trackHeight)

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
