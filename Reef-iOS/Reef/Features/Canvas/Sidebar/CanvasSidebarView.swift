import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool

    private var toolbarColor: Color {
        isDarkMode ? ReefColors.CanvasDark.toolbar : CanvasDrawingBar.barColor
    }

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 0) {
            // Leading separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 0.5)

            VStack(spacing: 0) {
                // Header matching toolbar rows (info strip 40pt + drawing bar 48pt)
                VStack(spacing: 0) {
                    // Info strip row — label shown here
                    HStack {
                        Text("Sidebar")
                            .font(.epilogue(13, weight: .black))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 40)

                    // Drawing bar row spacer
                    Color.clear
                        .frame(height: 48)

                    // Bottom separator
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 0.5)
                }
                .padding(.top, 12)
                .background(
                    ZStack {
                        toolbarColor
                        Color.black.opacity(isDarkMode ? 0.3 : 0.18)
                    }
                    .ignoresSafeArea(edges: .top)
                )

                // Content area
                VStack {
                    Spacer()
                    Text("Coming soon")
                        .font(.epilogue(14, weight: .medium))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
            }
        }
    }
}
