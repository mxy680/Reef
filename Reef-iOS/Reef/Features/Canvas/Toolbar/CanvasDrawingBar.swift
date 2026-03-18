import SwiftUI

// MARK: - Canvas Drawing Bar (Row 2)

struct CanvasDrawingBar: View {
    @Bindable var viewModel: CanvasViewModel

    /// The single toolbar teal.
    static let barColor = Color(hex: 0x4E8A97)
    private static let darkBarColor = ReefColors.CanvasDark.toolbar

    private var activeBarColor: Color {
        viewModel.isDarkMode ? Self.darkBarColor : Self.barColor
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(activeBarColor)
    }
}
