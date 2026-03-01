import SwiftUI

struct ReefTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.epilogue(16, weight: .medium))
            .tracking(-0.04 * 16)
            .foregroundStyle(ReefColors.black)
            .frame(height: 48)
            .padding(.horizontal, 18)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReefColors.black, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReefColors.black)
                    .offset(x: 2, y: 2)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
    }
}
