//
//  PageSettingsPopup.swift
//  Reef
//
//  Page overlay settings popup — grid, dots, or lines over PDF pages
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
    var showInExport: Bool = false
}

// MARK: - Popup View

struct PageSettingsPopup: View {
    @Binding var settings: PageOverlaySettings
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Page Settings")
                    .font(.epilogue(16, weight: .bold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(ReefColors.black)

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ReefColors.gray500)
                    .frame(width: 28, height: 28)
                    .background(ReefColors.gray100)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .onTapGesture { onDismiss() }
            }

            Spacer().frame(height: 20)

            // Overlay type segmented control
            Text("Overlay")
                .font(.epilogue(12, weight: .semiBold))
                .tracking(-0.04 * 12)
                .foregroundStyle(ReefColors.gray500)
                .padding(.bottom, 8)

            overlayTypePicker

            // Spacing slider (only when overlay is active)
            if settings.type != .none {
                Spacer().frame(height: 20)

                HStack {
                    Text("Spacing")
                        .font(.epilogue(12, weight: .semiBold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(ReefColors.gray500)

                    Spacer()

                    Text("\(Int(settings.spacing))pt")
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(ReefColors.black)
                }
                .padding(.bottom, 8)

                Slider(value: $settings.spacing, in: 10...60, step: 2)
                    .tint(ReefColors.primary)

                Spacer().frame(height: 20)

                // Show in export toggle
                HStack {
                    Text("Show in export")
                        .font(.epilogue(13, weight: .semiBold))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(ReefColors.black)

                    Spacer()

                    Toggle("", isOn: $settings.showInExport)
                        .labelsHidden()
                        .tint(ReefColors.primary)
                }
            }
        }
        .padding(24)
        .background(ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ReefColors.black)
                .offset(x: 4, y: 4)
        )
        .frame(maxWidth: 340)
    }

    // MARK: - Overlay Type Picker

    private var overlayTypePicker: some View {
        HStack(spacing: 0) {
            ForEach(PageOverlayType.allCases, id: \.self) { type in
                Text(type.label)
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(settings.type == type ? ReefColors.white : ReefColors.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(settings.type == type ? ReefColors.primary : ReefColors.white)
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
                .stroke(ReefColors.black, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReefColors.black)
                .offset(x: 3, y: 3)
        )
    }
}
