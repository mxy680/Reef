import SwiftUI

struct ReefTextField: View {
    @Environment(ReefTheme.self) private var theme
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .emailAddress
    var capitalization: TextInputAutocapitalization = .never

    var body: some View {
        let colors = theme.colors
        TextField(
            placeholder,
            text: $text,
            prompt: Text(placeholder).foregroundStyle(colors.textMuted)
        )
        .font(.epilogue(16, weight: .medium))
        .tracking(-0.04 * 16)
        .foregroundStyle(colors.text)
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
        .textInputAutocapitalization(capitalization)
        .autocorrectionDisabled()
        .keyboardType(keyboard)
    }
}
