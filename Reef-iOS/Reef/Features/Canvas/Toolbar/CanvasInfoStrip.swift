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

            // Center: doc name · pages · problems
            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Text(doc.displayName)
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundColor(.white)
                    .lineLimit(1)

                dotSeparator

                Text(doc.statusLabel)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Tutor mode toggle
            HStack(spacing: 8) {
                Image(viewModel.tutorModeOn ? "canvas.tutor_on" : "canvas.tutor_off")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)

                ReefToggle(isOn: $viewModel.tutorModeOn, size: .compact)
            }
            .padding(.trailing, 10)
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

    private var dotSeparator: some View {
        Text("  ·  ")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.35))
    }
}
