import SwiftUI

// MARK: - Add Color Popup (centered overlay)

struct CanvasAddColorPopup: View {
    let onAdd: (UIColor) -> Void
    let onDismiss: () -> Void
    @State private var selectedIndex: Int? = nil

    // 6 columns x 5 rows = 30 colors
    private static let palette: [UIColor] = [
        // Row 1 — neutrals
        .black,
        UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
        UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1),
        UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
        .white,
        // Row 2 — warm
        UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
        UIColor(red: 0.95, green: 0.4, blue: 0.3, alpha: 1),
        UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1),
        UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1),
        UIColor(red: 0.85, green: 0.4, blue: 0.6, alpha: 1),
        UIColor(red: 0.7, green: 0.2, blue: 0.35, alpha: 1),
        // Row 3 — cool
        UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
        UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1),
        UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1),
        UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
        UIColor(red: 0.5, green: 0.8, blue: 0.3, alpha: 1),
        UIColor(red: 0.0, green: 0.5, blue: 0.35, alpha: 1),
        // Row 4 — purples & pastels
        UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1),
        UIColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1),
        UIColor(red: 0.8, green: 0.6, blue: 0.9, alpha: 1),
        UIColor(red: 0.95, green: 0.75, blue: 0.8, alpha: 1),
        UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1),
        UIColor(red: 0.75, green: 0.95, blue: 0.75, alpha: 1),
        // Row 5 — earth & muted
        UIColor(red: 0.6, green: 0.4, blue: 0.25, alpha: 1),
        UIColor(red: 0.75, green: 0.55, blue: 0.35, alpha: 1),
        UIColor(red: 0.55, green: 0.55, blue: 0.45, alpha: 1),
        UIColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1),
        UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1),
        UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(spacing: 20) {
            Text("Pick a Color")
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { index, color in
                    let isSelected = selectedIndex == index
                    Button {
                        selectedIndex = index
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(ReefColors.black.opacity(0.6), lineWidth: 1.5)
                            )
                            .background(
                                Circle()
                                    .fill(ReefColors.black.opacity(0.5))
                                    .offset(x: 2, y: 2)
                            )
                            .overlay(
                                isSelected
                                    ? Circle().stroke(ReefColors.black, lineWidth: 3).frame(width: 38, height: 38)
                                    : nil
                            )
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                // Cancel button — 3D
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundColor(ReefColors.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ReefColors.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ReefColors.white)
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ReefColors.black, lineWidth: 2)
                            }
                        )
                }
                .buttonStyle(.plain)

                // Add button — 3D filled
                Button {
                    if let index = selectedIndex {
                        onAdd(Self.palette[index])
                    }
                } label: {
                    Text("Add")
                        .font(.epilogue(14, weight: .black))
                        .tracking(-0.04 * 14)
                        .foregroundColor(selectedIndex != nil ? .white : ReefColors.gray500)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedIndex != nil ? ReefColors.primary : ReefColors.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedIndex != nil ? ReefColors.black : ReefColors.gray400, lineWidth: selectedIndex != nil ? 2 : 1.5)
                        )
                        .compositingGroup()
                        .background(
                            selectedIndex != nil
                                ? AnyView(RoundedRectangle(cornerRadius: 10).fill(ReefColors.black).offset(x: 3, y: 3))
                                : AnyView(EmptyView())
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedIndex == nil)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ReefColors.black)
                    .offset(x: 4, y: 4)

                RoundedRectangle(cornerRadius: 16)
                    .fill(ReefColors.white)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(ReefColors.black, lineWidth: 2)
            }
        )
    }
}
