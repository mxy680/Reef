import SwiftUI

// MARK: - Canvas Toolbar Button

struct CanvasToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isCustomIcon: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
            .frame(width: 36, height: 36, alignment: .center)
            .background(
                isSelected
                    ? Color.white.opacity(0.25)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }
}
