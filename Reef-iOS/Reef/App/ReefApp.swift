@preconcurrency import GoogleSignIn
import SwiftUI
import UIKit

@main
struct ReefApp: App {
    @State private var auth: AuthViewModel
    @State private var theme = ReefTheme()

    init() {
        PointerInteractionDisabler.install()
        UIScrollView.appearance().backgroundColor = .clear
        UIView.appearance(
            whenContainedInInstancesOf: [UIHostingController<AnyView>.self]
        ).backgroundColor = .clear

        // Wire up dependencies
        let authRepo = SupabaseAuthRepository()
        let profileRepo = SupabaseProfileRepository()
        _auth = State(initialValue: AuthViewModel(
            authRepo: authRepo,
            profileRepo: profileRepo
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(auth)
                .environment(theme)
                .statusBarHidden(true)
                .onOpenURL { url in
                    auth.handleURL(url)
                }
        }
    }
}

// MARK: - iPadOS Pointer Highlight Killer

enum PointerInteractionDisabler {
    static func install() {
        let original = class_getInstanceMethod(
            UIView.self,
            #selector(UIView.addInteraction(_:))
        )
        let swizzled = class_getInstanceMethod(
            UIView.self,
            #selector(UIView.reef_addInteraction(_:))
        )
        if let original, let swizzled {
            method_exchangeImplementations(original, swizzled)
        }
    }
}

extension UIView {
    @objc fileprivate func reef_addInteraction(_ interaction: UIInteraction) {
        if interaction is UIPointerInteraction { return }
        reef_addInteraction(interaction)
    }
}
