import SwiftUI

struct MyReefComingSoonView: View {
    @State private var appeared = false
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero illustration area
                heroArea

                // Content area
                contentArea
            }
        }
        .dashboardCard()
        .onAppear { appeared = true }
    }

    // MARK: - Hero

    private var heroArea: some View {
        let dark = theme.isDarkMode
        return ZStack(alignment: .bottom) {
            Image("reef-hero")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()

            // Title overlay at bottom
            VStack(spacing: 6) {
                Text("My Reef")
                    .font(.epilogue(32, weight: .black))
                    .tracking(-0.04 * 32)
                    .foregroundStyle(ReefColors.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Text("Your personal ocean ecosystem")
                    .font(.epilogue(15, weight: .medium))
                    .tracking(-0.04 * 15)
                    .foregroundStyle(ReefColors.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                .frame(height: 1.5)
        }
    }

    // MARK: - Content

    private var contentArea: some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 0) {
            // Badge
            comingSoonBadge
                .padding(.bottom, 16)

            Text("Build Your Reef Ecosystem")
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .padding(.bottom, 10)

            Text("As you study and master new topics, you'll unlock species for your personal reef. Watch your ocean grow from a quiet sandy floor into a thriving coral ecosystem.")
                .font(.epilogue(15, weight: .medium))
                .tracking(-0.02 * 15)
                .lineSpacing(4)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .padding(.bottom, 20)

            // Feature cards
            featureCardsRow
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    private var comingSoonBadge: some View {
        let dark = theme.isDarkMode
        return HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(ReefColors.accent)
                .overlay(
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundStyle(dark ? ReefColors.DashboardDark.border : ReefColors.black)
                )

            Text("COMING SOON")
                .font(.epilogue(11, weight: .bold))
                .tracking(0.04 * 11)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(dark ? ReefColors.DashboardDark.surface : ReefColors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 2))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .animation(.easeOut(duration: 0.3).delay(0.35), value: appeared)
    }

    private var featureCardsRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(featureCards.enumerated()), id: \.element.title) { index, card in
                featureCard(card, index: index)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.3).delay(0.45), value: appeared)
    }

    private func featureCard(_ card: ReefFeatureCard, index: Int) -> some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: card.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Text(card.title)
                .font(.epilogue(13, weight: .bold))
                .tracking(-0.02 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.description)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.02 * 12)
                .lineSpacing(2)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(card.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(.easeOut(duration: 0.25).delay(0.50 + Double(index) * 0.07), value: appeared)
    }

    // MARK: - Data

    private struct ReefFeatureCard {
        let icon: String
        let title: String
        let description: String
        let background: Color
    }

    private let featureCards: [ReefFeatureCard] = [
        .init(
            icon: "fish.fill",
            title: "Unlock Species",
            description: "Earn new ocean creatures as you master topics.",
            background: ReefColors.accent
        ),
        .init(
            icon: "chart.bar.fill",
            title: "Track Mastery",
            description: "Watch your reef grow as subjects click into place.",
            background: ReefColors.surface
        ),
        .init(
            icon: "person.2.fill",
            title: "Compare Reefs",
            description: "See how your ecosystem stacks up with friends.",
            background: ReefColors.surface
        ),
    ]
}
