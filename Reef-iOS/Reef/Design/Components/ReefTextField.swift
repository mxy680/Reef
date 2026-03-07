import SwiftUI

struct ReefTextField: View {
    @Environment(ThemeManager.self) private var theme
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .emailAddress
    var capitalization: TextInputAutocapitalization = .never

    var body: some View {
        let dark = theme.isDarkMode
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500))
            .font(.epilogue(16, weight: .medium))
            .tracking(-0.04 * 16)
            .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
            .frame(height: 48)
            .padding(.horizontal, 18)
            .background(dark ? ReefColors.DashboardDark.input : ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(dark ? ReefColors.DashboardDark.inputBorder : ReefColors.black, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dark ? ReefColors.DashboardDark.popupShadow : ReefColors.black)
                    .offset(x: 2, y: 2)
            )
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
    }
}
