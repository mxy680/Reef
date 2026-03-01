import SwiftUI

struct StepName: View {
    @Binding var name: String
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's your name?")
                .reefHeading()
                .padding(.bottom, 6)
                .fadeUp(index: 0)

            Text("We'll use this to personalize your experience.")
                .reefBody()
                .padding(.bottom, 24)
                .fadeUp(index: 1)

            ReefTextField(
                placeholder: "Your name",
                text: $name,
                keyboard: .default,
                capitalization: .words
            )
            .submitLabel(.continue)
            .onSubmit {
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    onNext()
                }
            }
            .padding(.bottom, 24)
            .fadeUp(index: 2)

            Button(action: onNext) {
                Text("Continue")
            }
            .reefStyle(.primary)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.7 : 1)
            .fadeUp(index: 3)
        }
    }
}
