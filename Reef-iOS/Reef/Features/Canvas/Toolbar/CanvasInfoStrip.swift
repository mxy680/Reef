import SwiftUI

// MARK: - Canvas Info Strip (Row 1)

struct CanvasInfoStrip: View {
    @Bindable var viewModel: CanvasViewModel

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

            Spacer(minLength: 8)

            // Battery
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
            .padding(.trailing, 18)

            #if targetEnvironment(simulator)
            divider

            // Pan/Draw toggle for simulator (no Apple Pencil)
            Button {
                viewModel.simulatorPanMode.toggle()
            } label: {
                Image(systemName: viewModel.simulatorPanMode ? "hand.raised.fill" : "pencil.tip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.simulatorPanMode ? .yellow : .white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            #endif
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

    // MARK: - Helpers

    private var divider: some View {
        Text("|")
            .font(.system(size: 18, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.3))
            .frame(width: 16)
    }
}
