@preconcurrency import GoogleSignIn
import SwiftUI
import UIKit

@main
struct ReefApp: App {
    @State private var authManager = AuthManager()
    @State private var themeManager = ThemeManager()

    init() {
        PointerInteractionDisabler.install()
        // Force all UIKit backing views to have clear backgrounds so
        // SwiftUI doesn't briefly flash the system gray during layout.
        UIScrollView.appearance().backgroundColor = .clear
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(themeManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    Task { try? await supabase.auth.session(from: url) }
                }
        }
    }
}

// MARK: - Global iPadOS Pointer Highlight Killer
//
// iPadOS automatically adds UIPointerInteraction to any UIView
// that has gesture recognizers, causing a gray highlight rectangle
// on hover/tap. SwiftUI's .hoverEffectDisabled() doesn't reach
// this UIKit layer. This swizzle strips every UIPointerInteraction
// the moment it's added, globally and permanently.

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
        // Block UIPointerInteraction from being added
        if interaction is UIPointerInteraction { return }
        // Call original (swizzled) implementation for everything else
        reef_addInteraction(interaction)
    }
}
