import SwiftUI

// MARK: - Canvas Info Strip (Row 1)

struct CanvasInfoStrip: View {
    @Bindable var viewModel: CanvasViewModel
    var walkthroughStep: WalkthroughStep? = nil

    let onClose: () -> Void

    private var activeBarColor: Color {
        viewModel.isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasDrawingBar.barColor
    }

    private var doc: Document { viewModel.document }

    var body: some View {
        HStack(spacing: 0) {
            // Home button
            Button(action: onClose) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)

            // Wifi status indicator
            Image(viewModel.isWifiConnected ? "canvas.wifi_on" : "canvas.wifi_off")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(viewModel.isWifiConnected ? .white.opacity(0.7) : Color(hex: 0xE57373))
                .frame(width: 32, height: 36)

            divider

            // Doc icon + name + timer
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Text(doc.displayName.count > 12 ? String(doc.displayName.prefix(12)) + "..." : doc.displayName)
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))

                    Text(viewModel.studyTimerLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            // Step hint — tutor mode only
            if viewModel.tutorModeOn {
                divider

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Step \(viewModel.currentTutorStepIndex + 1)/\(viewModel.tutorStepCount):")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Text(LaTeXToUnicode.convert(viewModel.currentTutorStepLabel))
                        .font(.epilogue(11, weight: .medium))
                        .tracking(-0.04 * 11)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .transition(.opacity)
            }

            Spacer(minLength: 8)

            // "Generating tutor..." centered in toolbar while answer keys load
            if viewModel.isReconstructed && viewModel.isLoadingAnswerKeys && viewModel.answerKeys.isEmpty {
                Text("Generating tutor — hang tight...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .transition(.opacity)

                Spacer(minLength: 8)
            }

            if viewModel.tutorModeOn {
                // Tutor mode: progress bar | hint + reveal
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        progressBar(progress: viewModel.tutorProgress)

                        Text("\(Int(viewModel.tutorProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    divider

                    Button {
                        viewModel.showHintPopover.toggle()
                        if viewModel.showHintPopover { viewModel.showRevealPopover = false }
                    } label: {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(viewModel.showHintPopover ? 1 : 0.8))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                            .walkthroughGlow(active: walkthroughStep?.targetButton == .hint)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.showRevealPopover.toggle()
                        if viewModel.showRevealPopover { viewModel.showHintPopover = false }
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                            .walkthroughGlow(active: walkthroughStep?.targetButton == .reveal)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            } else {
                // Normal mode: battery
                HStack(spacing: 3) {
                    Image(viewModel.batteryIconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white.opacity(0.55))

                    Text("\(viewModel.batteryPercentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                .transition(.opacity)
            }

            divider

            // Tutor mode toggle
            HStack(spacing: 8) {
                Image(viewModel.tutorModeOn ? "canvas.tutor_on" : "canvas.tutor_off")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white.opacity(viewModel.isReconstructed && !viewModel.answerKeys.isEmpty ? 1 : 0.4))
                    .walkthroughGlow(active: walkthroughStep?.targetButton == .tutorToggle)

                if viewModel.isReconstructed && !viewModel.answerKeys.isEmpty {
                    ReefToggle(isOn: Binding(
                        get: { viewModel.tutorModeOn },
                        set: { newValue in
                            viewModel.tutorModeOn = newValue
                            if !newValue {
                                viewModel.showSidebar = false
                            }
                        }
                    ), size: .compact)
                } else {
                    ReefToggle(isOn: .constant(false), size: .compact)
                        .disabled(true)
                        .opacity(0.5)
                }
            }
            .padding(.trailing, 18)
            .animation(.easeInOut(duration: 0.3), value: viewModel.answerKeys.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            ZStack {
                activeBarColor
                Color.black.opacity(viewModel.isDarkMode ? 0.3 : 0.18)
            }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.tutorModeOn)
    }

    // MARK: - 3D Progress Bar

    private func progressBar(progress: Double) -> some View {
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
    }

    private func progressFillColor(for progress: Double) -> Color {
        if progress < 0.5 {
            return .white.opacity(0.85)
        } else if progress < 0.8 {
            return ReefColors.accent
        } else {
            return Color(hex: 0x81C784)
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Text("|")
            .font(.system(size: 18, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.3))
            .frame(width: 16)
    }
}
