import SwiftUI

struct PaywallStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    @State private var selectedPlan = 1  // 0=hours, 1=unlimited monthly, 2=unlimited annual

    private var greeting: String {
        let name = auth.displayName
        if name.isEmpty || name == "User" {
            return "Pick your plan."
        }
        return "\(name), pick your plan."
    }

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Greeting
                    Text(greeting)
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.center)
                        .fadeUp(index: 0)

                    // Free hours callout
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ReefColors.primary)
                        Text("You get 3 free hours of tutoring. No card needed.")
                            .font(.epilogue(13, weight: .semiBold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ReefColors.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .fadeUp(index: 1)

                    // Plan cards
                    VStack(spacing: 12) {
                        // Hour packs
                        planCard(
                            title: "Pay as you go",
                            price: "$1.99/hour",
                            detail: "Buy hours when you need them. No commitment.",
                            planIndex: 0,
                            badge: nil
                        )
                        .fadeUp(index: 2)

                        // Unlimited monthly
                        planCard(
                            title: "Unlimited",
                            price: "$29.99/mo",
                            detail: "Unlimited tutoring, all courses, all features.",
                            planIndex: 1,
                            badge: "Most Popular"
                        )
                        .fadeUp(index: 3)

                        // Unlimited annual
                        planCard(
                            title: "Unlimited Annual",
                            price: "$179.99/yr",
                            detail: "$15/mo — save 50% vs monthly.",
                            planIndex: 2,
                            badge: "Best Value"
                        )
                        .fadeUp(index: 4)
                    }

                    // Hour packs detail (shown when hours selected)
                    if selectedPlan == 0 {
                        VStack(spacing: 8) {
                            hourRow(hours: "5 hours", price: "$7.99", perHour: "$1.60/hr", savings: "20% off")
                            hourRow(hours: "10 hours", price: "$13.99", perHour: "$1.40/hr", savings: "30% off")
                            hourRow(hours: "20 hours", price: "$24.99", perHour: "$1.25/hr", savings: "37% off")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colors.border, lineWidth: 1.5)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // CTA
                    ReefButton("Continue with free hours", action: { viewModel.goNext() })
                        .fadeUp(index: 5)

                    // Restore
                    ReefButton(.ghost, action: { viewModel.goNext() }) {
                        Text("Restore Purchases")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                    }
                }
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Plan Card

    private func planCard(
        title: String,
        price: String,
        detail: String,
        planIndex: Int,
        badge: String?
    ) -> some View {
        let colors = theme.colors
        let isSelected = selectedPlan == planIndex

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.epilogue(17, weight: .bold))
                    .tracking(-0.04 * 17)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)

                if let badge {
                    Text(badge)
                        .font(.epilogue(10, weight: .bold))
                        .tracking(-0.02 * 10)
                        .foregroundStyle(isSelected ? ReefColors.primary : ReefColors.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isSelected ? ReefColors.white : ReefColors.primary)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(price)
                    .font(.epilogue(16, weight: .bold))
                    .tracking(-0.04 * 16)
                    .foregroundStyle(isSelected ? ReefColors.white : colors.text)
            }

            Text(detail)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(isSelected ? ReefColors.white.opacity(0.8) : colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isSelected ? ReefColors.primary : colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .reef3DPush(
            cornerRadius: 14,
            borderWidth: 2,
            borderColor: colors.border,
            shadowColor: colors.shadow,
            action: {
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    selectedPlan = planIndex
                }
            }
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }

    // MARK: - Hour Pack Row

    private func hourRow(hours: String, price: String, perHour: String, savings: String) -> some View {
        let colors = theme.colors

        return HStack {
            Text(hours)
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)

            Spacer()

            Text(perHour)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(colors.textMuted)

            Text(price)
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)
                .frame(width: 60, alignment: .trailing)

            Text(savings)
                .font(.epilogue(10, weight: .bold))
                .tracking(-0.02 * 10)
                .foregroundStyle(ReefColors.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ReefColors.primary.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}
