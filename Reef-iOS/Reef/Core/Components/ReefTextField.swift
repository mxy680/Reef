import SwiftUI

// MARK: - Text Field with 3D Shadow

struct ReefTextField: View {
    @Environment(ReefTheme.self) private var theme

    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var autocorrection: Bool = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        let colors = theme.colors

        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            }

            TextField(
                placeholder,
                text: $text,
                prompt: Text(placeholder).foregroundStyle(colors.textMuted)
            )
            .font(.epilogue(16, weight: .medium))
            .tracking(-0.04 * 16)
            .foregroundStyle(colors.text)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(!autocorrection)
            .keyboardType(keyboard)
            .onSubmit { onSubmit?() }
        }
        .frame(height: 48)
        .padding(.horizontal, 18)
        .background(colors.input)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.inputBorder, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.shadow)
                .offset(x: 2, y: 2)
        )
    }
}
