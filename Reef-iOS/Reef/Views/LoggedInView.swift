import SwiftUI

struct LoggedInView: View {
    var onOpenCanvas: (Document) -> Void

    var body: some View {
        DashboardView(onOpenCanvas: onOpenCanvas)
    }
}
