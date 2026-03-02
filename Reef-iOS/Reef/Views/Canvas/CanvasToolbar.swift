import SwiftUI

struct CanvasToolbar: View {
    let documentName: String
    let fingerDrawing: Bool
    let onClose: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onToggleFingerDrawing: () -> Void

    var body: some View {
        HStack {
            // Close button
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ReefColors.gray600)
                .frame(width: 36, height: 36)
                .background(ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ReefColors.gray400, lineWidth: 1.5)
                )
                .compositingGroup()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)

            Spacer()

            // Document title
            Text(documentName)
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(ReefColors.black)
                .lineLimit(1)

            Spacer()

            // Tool buttons
            HStack(spacing: 8) {
                toolbarButton(icon: "arrow.uturn.backward", action: onUndo)
                toolbarButton(icon: "arrow.uturn.forward", action: onRedo)

                // Finger drawing toggle
                Image(systemName: fingerDrawing ? "hand.draw.fill" : "hand.draw")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(fingerDrawing ? ReefColors.primary : ReefColors.gray600)
                    .frame(width: 36, height: 36)
                    .background(fingerDrawing ? ReefColors.primary.opacity(0.12) : ReefColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(fingerDrawing ? ReefColors.primary : ReefColors.gray400, lineWidth: 1.5)
                    )
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleFingerDrawing() }
                    .accessibilityLabel(fingerDrawing ? "Disable finger drawing" : "Enable finger drawing")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ReefColors.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ReefColors.gray200).frame(height: 1)
        }
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(ReefColors.gray600)
            .frame(width: 36, height: 36)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ReefColors.gray400, lineWidth: 1.5)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .accessibilityAddTraits(.isButton)
    }
}
