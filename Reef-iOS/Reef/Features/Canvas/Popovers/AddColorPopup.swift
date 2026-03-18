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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 18) {
            Text("Pick a Color")
                .font(.system(size: 16, weight: .bold))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { index, color in
                    let isSelected = selectedIndex == index
                    Button {
                        selectedIndex = index
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ? ReefColors.black : ReefColors.gray200,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                                    .padding(isSelected ? -2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ReefColors.gray600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(ReefColors.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    if let index = selectedIndex {
                        onAdd(Self.palette[index])
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selectedIndex != nil ? ReefColors.primary : ReefColors.gray400)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(selectedIndex == nil)
            }
        }
        .padding(20)
        .frame(width: 280)
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
