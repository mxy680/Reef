//
//  PageSettingsPopup.swift
//  Reef
//
//  Page overlay settings popover — grid, dots, or lines over PDF pages
//

import SwiftUI

// MARK: - Model

enum PageOverlayType: String, CaseIterable {
    case none, grid, dots, lines

    var label: String {
        switch self {
        case .none:  return "None"
        case .grid:  return "Grid"
        case .dots:  return "Dots"
        case .lines: return "Lines"
        }
    }
}

struct PageOverlaySettings: Equatable {
    var type: PageOverlayType = .none
    var spacing: CGFloat = 20
    var opacity: CGFloat = 0.35
    var showInExport: Bool = false
}

// MARK: - Popover View

struct PageSettingsPopover: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var settings: PageOverlaySettings

    var body: some View {
        let dark = theme.isDarkMode
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Page Settings")
                .font(.epilogue(15, weight: .bold))
                .tracking(-0.04 * 15)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Spacer().frame(height: 4)

            Text("Add an overlay to your pages.")
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray500)

            Spacer().frame(height: 16)

            // Overlay type segmented control
            Text("Overlay")
                .font(.epilogue(11, weight: .semiBold))
                .tracking(-0.04 * 11)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray400)
                .textCase(.uppercase)
                .padding(.bottom, 6)

            overlayTypePicker(dark: dark)

            // Spacing slider (only when overlay is active)
            if settings.type != .none {
                Spacer().frame(height: 16)

                HStack {
                    Text("Spacing")
                        .font(.epilogue(11, weight: .semiBold))
                        .tracking(-0.04 * 11)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray400)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(Int(settings.spacing))pt")
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                }
                .padding(.bottom, 6)

                Slider(value: $settings.spacing, in: 10...60, step: 2)
                    .tint(ReefColors.primary)

                Spacer().frame(height: 16)

                HStack {
                    Text("Opacity")
                        .font(.epilogue(11, weight: .semiBold))
                        .tracking(-0.04 * 11)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray400)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(Int(settings.opacity * 100))%")
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                }
                .padding(.bottom, 6)

                Slider(value: $settings.opacity, in: 0.1...1.0, step: 0.05)
                    .tint(ReefColors.primary)

                Spacer().frame(height: 16)

                // Show in export toggle
                HStack {
                    Text("Show in export")
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                    Spacer()

                    Toggle("", isOn: $settings.showInExport)
                        .labelsHidden()
                        .tint(ReefColors.primary)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    // MARK: - Overlay Type Picker

    private func overlayTypePicker(dark: Bool) -> some View {
        let borderColor = dark ? ReefColors.DashboardDark.popupBorder : ReefColors.black
        let bgColor = dark ? ReefColors.DashboardDark.card : ReefColors.white

        return HStack(spacing: 0) {
            ForEach(PageOverlayType.allCases, id: \.self) { type in
                Text(type.label)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(settings.type == type ? ReefColors.white : (dark ? ReefColors.DashboardDark.text : ReefColors.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(settings.type == type ? ReefColors.primary : bgColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            settings.type = type
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
                .fill(dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black)
                .offset(x: 3, y: 3)
        )
    }
}
