import SwiftUI

struct PaywallStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel

    @State private var selectedPlan = 0  // 0=free, 1=hourly, 2=unlimited
    @State private var isAnnual = false

    var body: some View {
        let colors = theme.colors

        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                // Card
                VStack(spacing: 0) {
                    // Header — free hours hero
                    VStack(spacing: 12) {
                        Text("🎉")
                            .font(.system(size: 36))

                        Text("3 free hours on us")
                            .font(.epilogue(26, weight: .black))
                            .tracking(-0.04 * 26)
                            .foregroundStyle(ReefColors.white)

                        Text("No credit card. No catch. Just start studying.")
                            .font(.epilogue(14, weight: .medium))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.white.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(ReefColors.primary)

                    // Annual toggle
                    HStack(spacing: 10) {
                        Text("Monthly")
                            .font(.epilogue(13, weight: isAnnual ? .medium : .bold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(isAnnual ? colors.textMuted : colors.text)

                        // Toggle pill
                        ZStack {
                            Capsule()
                                .fill(isAnnual ? ReefColors.primary : colors.subtle)
                                .frame(width: 48, height: 28)
                                .overlay(
                                    Capsule()
                                        .stroke(colors.border, lineWidth: 1.5)
                                )

                            Circle()
                                .fill(ReefColors.white)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(colors.border, lineWidth: 1)
                                )
                                .offset(x: isAnnual ? 10 : -10)
                        }
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.25)) {
                                isAnnual.toggle()
                            }
                        }

                        HStack(spacing: 4) {
                            Text("Annual")
                                .font(.epilogue(13, weight: isAnnual ? .bold : .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(isAnnual ? colors.text : colors.textMuted)

                            if isAnnual {
                                Text("SAVE 50%")
                                    .font(.epilogue(9, weight: .black))
                                    .tracking(0.5)
                                    .foregroundStyle(ReefColors.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ReefColors.primary)
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.vertical, 16)

                    // Plans
                    VStack(spacing: 10) {
                        // Free plan
                        planRow(
                            title: "Free",
                            price: "3 hours",
                            subtitle: "No expiry. Use them whenever.",
                            planIndex: 0,
                            badge: "RECOMMENDED"
                        )

                        // Pay as you go
                        planRow(
                            title: "Pay as you go",
                            price: "$1.99/hr",
                            subtitle: "Buy hours when you need them",
                            planIndex: 1,
                            badge: nil
                        )

                        // Unlimited
                        planRow(
                            title: "Unlimited",
                            price: isAnnual ? "$15/mo" : "$29.99/mo",
                            subtitle: isAnnual
                                ? "$179.99 billed annually"
                                : "Everything. No limits.",
                            planIndex: 2,
                            badge: nil
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // CTA
                    VStack(spacing: 12) {
                        ReefButton(
                            selectedPlan == 0
                                ? "Start with 3 free hours"
                                : selectedPlan == 1
                                    ? "Get started"
                                    : isAnnual
                                        ? "Subscribe — $179.99/year"
                                        : "Subscribe — $29.99/month",
                            action: { viewModel.goNext() }
                        )

                        Button(action: { viewModel.goNext() }) {
                            Text("Restore Purchases")
                                .font(.epilogue(12, weight: .medium))
                                .tracking(-0.04 * 12)
                                .foregroundStyle(colors.textMuted)
                        }
                        .buttonStyle(NoHighlightButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(colors.border, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.shadow)
                        .offset(x: 5, y: 5)
                )
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Plan Row

    private func planRow(
        title: String,
        price: String,
        subtitle: String,
        planIndex: Int,
        badge: String?
    ) -> some View {
        let colors = theme.colors
        let isSelected = selectedPlan == planIndex

        return HStack(spacing: 14) {
            // Radio circle
            ZStack {
                Circle()
                    .stroke(isSelected ? ReefColors.primary : colors.border, lineWidth: 2)
                    .frame(width: 22, height: 22)

                if isSelected {
                    Circle()
                        .fill(ReefColors.primary)
                        .frame(width: 14, height: 14)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.epilogue(15, weight: .bold))
                        .tracking(-0.04 * 15)
                        .foregroundStyle(colors.text)

                    if let badge {
                        Text(badge)
                            .font(.epilogue(9, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(ReefColors.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ReefColors.primary)
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Text(price)
                .font(.epilogue(15, weight: .bold))
                .tracking(-0.04 * 15)
                .foregroundStyle(isSelected ? ReefColors.primary : colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? ReefColors.primary.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? ReefColors.primary : colors.divider, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                selectedPlan = planIndex
            }
        }
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}
