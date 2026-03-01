import SwiftUI

/// Card style for dashboard panels (sidebar, header, content).
/// Uses gray500 borders and a subtle 3pt offset shadow,
/// distinct from the auth-screen ReefCard (black border, 6pt shadow).
struct DashboardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ReefColors.gray500, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ReefColors.gray500)
                    .offset(x: 3, y: 3)
            )
    }
}

extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}
