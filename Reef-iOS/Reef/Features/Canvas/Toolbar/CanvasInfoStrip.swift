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

            divider

            // Page indicator pill
            Text("Page \(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())

            divider

            // Doc icon + name + stats
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Text(doc.displayName)
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("·")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))

                Text(doc.statusLabel)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Battery
            HStack(spacing: 4) {
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

            divider

            // Dark mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.isDarkMode.toggle()
                }
            } label: {
                Image(systemName: viewModel.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    private var divider: some View {
        Text("|")
            .font(.system(size: 18, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.3))
            .frame(width: 16)
    }
}
