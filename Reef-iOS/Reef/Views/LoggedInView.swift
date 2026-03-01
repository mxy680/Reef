import SwiftUI

struct LoggedInView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            ReefColors.surface
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("You're In!")
                    .reefHeading()

                if let email = authManager.session?.user.email {
                    Text(email)
                        .reefBody()
                }

                Button {
                    authManager.signOut()
                } label: {
                    Text("Sign Out")
                }
                .reefStyle(.secondary)
                .frame(maxWidth: 200)
            }
        }
    }
}
