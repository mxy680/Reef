import SwiftUI
import PencilKit

// MARK: - Eraser Settings Content (inside PopoverCard)

struct CanvasEraserSettingsContent: View {
    @Bindable var viewModel: CanvasViewModel

    var body: some View {
        VStack(spacing: 10) {
            Picker("Eraser Mode", selection: $viewModel.eraserMode) {
                Text("Stroke").tag(PKEraserTool.EraserType.vector)
                Text("Pixel").tag(PKEraserTool.EraserType.bitmap)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: 4, height: 4)

                Slider(value: $viewModel.eraserWidth, in: 4...40)
                    .tint(.gray)

                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Circle().fill(Color.gray.opacity(0.15)))
                    .frame(
                        width: min(viewModel.eraserWidth * 0.5, 16),
                        height: min(viewModel.eraserWidth * 0.5, 16)
                    )
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 190)
    }
}
