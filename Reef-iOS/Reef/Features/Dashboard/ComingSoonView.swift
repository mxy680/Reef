import SwiftUI

struct ComingSoonView: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics
    @State private var appeared = false

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ReefColors.primary.opacity(0.6))
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

            Text(title)
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(colors.text)
                .textCase(.uppercase)
                .padding(.bottom, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

            Text(subtitle)
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

            Text("Coming Soon")
                .font(.epilogue(11, weight: .bold))
                .tracking(0.06 * 11)
                .textCase(.uppercase)
                .foregroundStyle(ReefColors.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(ReefColors.primary.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(metrics.contentPadding)
        .dashboardCard()
        .onAppear { appeared = true }
    }
}
