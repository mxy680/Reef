import SwiftUI

// MARK: - Page Settings Content (inside PopoverCard)

struct CanvasPageSettingsContent: View {
    @Bindable var viewModel: CanvasViewModel

    private var isDark: Bool { viewModel.isDarkMode }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Page Settings")
                .font(.epilogue(15, weight: .bold))
                .tracking(-0.04 * 15)
                .foregroundStyle(isDark ? ReefColors.Dark.text : ReefColors.black)

            Spacer().frame(height: 4)

            Text("Add an overlay to your pages.")
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(isDark ? ReefColors.Dark.textSecondary : ReefColors.gray500)

            Spacer().frame(height: 16)

            Text("Overlay")
                .font(.epilogue(11, weight: .semiBold))
                .tracking(-0.04 * 11)
                .foregroundStyle(isDark ? ReefColors.Dark.textMuted : ReefColors.gray400)
                .textCase(.uppercase)
                .padding(.bottom, 6)

            overlayTypePicker

            if viewModel.overlaySettings.type != .none {
                Spacer().frame(height: 16)

                HStack {
                    Text("Spacing")
                        .font(.epilogue(11, weight: .semiBold))
                        .tracking(-0.04 * 11)
                        .foregroundStyle(isDark ? ReefColors.Dark.textMuted : ReefColors.gray400)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(viewModel.overlaySettings.spacing))pt")
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(isDark ? ReefColors.Dark.text : ReefColors.black)
                }
                .padding(.bottom, 6)

                Slider(value: $viewModel.overlaySettings.spacing, in: 10...60, step: 2)
                    .tint(ReefColors.primary)

                Spacer().frame(height: 16)

                HStack {
                    Text("Opacity")
                        .font(.epilogue(11, weight: .semiBold))
                        .tracking(-0.04 * 11)
                        .foregroundStyle(isDark ? ReefColors.Dark.textMuted : ReefColors.gray400)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(viewModel.overlaySettings.opacity * 100))%")
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(isDark ? ReefColors.Dark.text : ReefColors.black)
                }
                .padding(.bottom, 6)

                Slider(value: $viewModel.overlaySettings.opacity, in: 0.1...1.0, step: 0.05)
                    .tint(ReefColors.primary)

                Spacer().frame(height: 16)

                HStack {
                    Text("Show in export")
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(isDark ? ReefColors.Dark.text : ReefColors.black)
                    Spacer()
                    Toggle("", isOn: $viewModel.overlaySettings.showInExport)
                        .labelsHidden()
                        .tint(ReefColors.primary)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    // MARK: - Overlay Type Picker

    private var overlayTypePicker: some View {
        let borderColor = isDark ? ReefColors.Dark.popupBorder : ReefColors.black
        let bgColor = isDark ? ReefColors.Dark.card : ReefColors.white

        return HStack(spacing: 0) {
            ForEach(CanvasOverlayType.allCases, id: \.self) { type in
                Text(type.label)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(
                        viewModel.overlaySettings.type == type
                            ? ReefColors.white
                            : (isDark ? ReefColors.Dark.text : ReefColors.black)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.overlaySettings.type == type ? ReefColors.primary : bgColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.overlaySettings.type = type
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDark ? ReefColors.Dark.popupShadow : ReefColors.black)
                .offset(x: 3, y: 3)
        )
    }
}
