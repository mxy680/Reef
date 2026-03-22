import SwiftUI
import PencilKit

// MARK: - Tool Settings Content (inside PopoverCard)

struct CanvasToolSettingsContent: View {
    @Bindable var viewModel: CanvasViewModel

    private var allColors: [UIColor] {
        Self.defaultColors + viewModel.customColors
    }

    static let defaultColors: [UIColor] = [
        .black,
        UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
        UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
    ]

    private static let visibleCount = 5

    var body: some View {
        VStack(spacing: 10) {
            colorRow

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(viewModel.penColor))
                    .frame(width: 4, height: 4)

                Slider(value: $viewModel.penWidth, in: 0.5...8.0)
                    .tint(Color(viewModel.penColor))

                Circle()
                    .fill(Color(viewModel.penColor))
                    .frame(width: viewModel.penWidth * 2, height: viewModel.penWidth * 2)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 190)
    }

    // MARK: - Color Row

    @ViewBuilder
    private var colorRow: some View {
        let totalItems = allColors.count + 1
        let needsScroll = totalItems > Self.visibleCount

        if needsScroll {
            ScrollView(.horizontal, showsIndicators: false) {
                colorButtons
            }
        } else {
            colorButtons
        }
    }

    private var colorButtons: some View {
        HStack(spacing: 10) {
            ForEach(Array(allColors.enumerated()), id: \.offset) { _, color in
                colorCircle(color: color, isSelected: viewModel.penColor == color)
            }

            Button {
                viewModel.showAddColor = true
                viewModel.showToolSettings = false
            } label: {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(ReefColors.gray400, lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ReefColors.gray400)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func colorCircle(color: UIColor, isSelected: Bool) -> some View {
        Button {
            viewModel.penColor = color
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? ReefColors.black : Color.clear,
                            lineWidth: isSelected ? 1.5 : 0
                        )
                        .padding(-2)
                )
        }
        .buttonStyle(.plain)
    }
}
