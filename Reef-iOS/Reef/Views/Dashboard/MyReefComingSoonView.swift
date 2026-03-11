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
        return ZStack {
            // Ocean gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.90, blue: 0.95),
                    ReefColors.accent
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Animated floating bubbles
            FloatingBubblesView(dark: dark)

            // Emoji heroes + title
            VStack(spacing: 24) {
                // Emoji arrangement
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Text("🐠")
                            .font(.system(size: 56))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                        Text("🪸")
                            .font(.system(size: 72))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.0), value: appeared)

                        Text("🐠")
                            .font(.system(size: 44))
                            .scaleEffect(x: -1, y: 1) // mirror for variety
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.10), value: appeared)
                    }

                    HStack(spacing: 32) {
                        Text("🐚")
                            .font(.system(size: 40))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                        Text("🦀")
                            .font(.system(size: 44))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.easeOut(duration: 0.4).delay(0.20), value: appeared)
                    }
                }

                VStack(spacing: 6) {
                    Text("My Reef")
                        .font(.epilogue(32, weight: .black))
                        .tracking(-0.04 * 32)
                        .foregroundStyle(ReefColors.black)

                    Text("Your personal ocean ecosystem")
                        .font(.epilogue(15, weight: .medium))
                        .tracking(-0.04 * 15)
                        .foregroundStyle(ReefColors.gray600)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.25), value: appeared)
            }
            .padding(.vertical, 48)
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

// MARK: - Floating Bubbles

private struct FloatingBubblesView: View {
    let dark: Bool

    // Fixed set of bubbles so the layout stays stable across re-renders
    private let bubbles: [BubbleSpec] = [
        .init(id: 0, x: 0.12, size: 18, duration: 5.8, delay: 0.0),
        .init(id: 1, x: 0.28, size: 10, duration: 4.5, delay: 1.2),
        .init(id: 2, x: 0.45, size: 24, duration: 6.5, delay: 0.4),
        .init(id: 3, x: 0.62, size: 14, duration: 5.2, delay: 2.1),
        .init(id: 4, x: 0.78, size: 8,  duration: 4.0, delay: 0.9),
        .init(id: 5, x: 0.90, size: 20, duration: 6.0, delay: 1.7),
        .init(id: 6, x: 0.35, size: 12, duration: 5.5, delay: 3.0),
        .init(id: 7, x: 0.68, size: 16, duration: 4.8, delay: 0.5),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(bubbles) { bubble in
                FloatingBubble(
                    spec: bubble,
                    containerWidth: geo.size.width,
                    containerHeight: geo.size.height,
                    dark: dark
                )
            }
        }
        .allowsHitTesting(false)
    }

    fileprivate struct BubbleSpec: Identifiable {
        let id: Int
        let x: CGFloat        // fractional horizontal position 0–1
        let size: CGFloat
        let duration: Double
        let delay: Double
    }
}

private struct FloatingBubble: View {
    let spec: FloatingBubblesView.BubbleSpec
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let dark: Bool

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(
                dark
                    ? Color.white.opacity(0.07)
                    : Color.white.opacity(0.45)
            )
            .overlay(
                Circle()
                    .stroke(
                        dark
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.7),
                        lineWidth: 1
                    )
            )
            .frame(width: spec.size, height: spec.size)
            .position(
                x: spec.x * containerWidth,
                y: containerHeight - spec.size / 2 + offset
            )
            .opacity(opacity)
            .onAppear {
                // Start from bottom, float upward past the top
                let travel = containerHeight + spec.size + 20
                withAnimation(
                    .easeInOut(duration: spec.duration)
                    .delay(spec.delay)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = -travel
                }
                withAnimation(.easeIn(duration: 0.6).delay(spec.delay)) {
                    opacity = 1
                }
            }
    }
}
