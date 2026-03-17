import SwiftUI

// MARK: - Settings Account Tab

struct SettingsAccountTab: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.reefLayoutMetrics) private var metrics

    let onToast: (String) -> Void

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false

    private let currentTier: Tier = .shore
    private var limits: TierLimits { TierLimits.forTier(currentTier) }

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 0) {
            // Row 1: Current Plan | Security
            HStack(alignment: .top, spacing: 0) {
                planContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)

                Rectangle().fill(colors.divider).frame(width: 1)

                securityContent(colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(metrics.cardPadding)
            }

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 2: Compare Plans (full width)
            comparePlansContent(colors)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(metrics.cardPadding)

            Rectangle().fill(colors.divider).frame(height: 1)

            // Row 3: Danger Zone (full width)
            dangerZoneContent(colors)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(metrics.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onToast("Account deletion is not yet available.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
    }

    // MARK: - Current Plan Cell

    private func planContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Current Plan")
                .padding(.bottom, -2)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(currentTier.rawValue.capitalized)
                            .font(.epilogue(18, weight: .black))
                            .tracking(-0.04 * 18)
                            .foregroundStyle(colors.text)

                        Text("FREE BETA")
                            .font(.epilogue(10, weight: .black))
                            .tracking(0.02 * 10)
                            .foregroundStyle(colors.text)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colors.border, lineWidth: 1.5)
                            )
                    }

                    Text("Access all features during the beta period")
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()
            }

            usageBar(
                label: "Documents",
                used: 2,
                max: limits.maxDocuments,
                color: ReefColors.primary,
                colors: colors
            )

            usageBar(
                label: "Courses",
                used: 1,
                max: limits.maxCourses,
                color: ReefColors.accent,
                colors: colors
            )

            usageBar(
                label: "File Size Limit",
                used: 12,
                max: limits.maxFileSizeMB,
                color: Color(hex: 0x81B29A),
                colors: colors
            )
        }
    }

    private func usageBar(
        label: String,
        used: Int,
        max: Int,
        color: Color,
        colors: ReefThemeColors
    ) -> some View {
        let pct: CGFloat = max == Int.max ? 0.1 : CGFloat(used) / CGFloat(max)
        let maxLabel = max == Int.max ? "Unlimited" : "\(max)"
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.epilogue(12, weight: .semiBold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text("\(used) / \(maxLabel)")
                    .font(.epilogue(12, weight: .bold))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.subtle)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(pct, 1))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Security Cell

    private func securityContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Security")
                .padding(.bottom, 14)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign-in Method")
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)
                    Text(signInMethodLabel)
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                Image(systemName: signInMethodIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(colors.textSecondary)
            }

            SettingsDivider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("User ID")
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)

                    Text(auth.profile?.id ?? auth.session?.userId ?? "—")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(colors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
        }
    }

    private var signInMethodLabel: String {
        guard let email = auth.session?.email else { return "Unknown" }
        if email.isEmpty { return "Apple Sign In" }
        return "Magic Link — \(email)"
    }

    private var signInMethodIcon: String {
        "envelope.badge.shield.half.filled"
    }

    // MARK: - Compare Plans Cell

    private func comparePlansContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(title: "Compare Plans")
            HStack(alignment: .top, spacing: 12) {
                planCard(
                    tier: .shore,
                    price: "Free",
                    features: ["5 documents", "1 course", "20 MB files"],
                    isCurrent: currentTier == .shore
                )
                planCard(
                    tier: .reef,
                    price: "$8/mo",
                    features: ["50 documents", "5 courses", "50 MB files"],
                    isCurrent: currentTier == .reef
                )
                planCard(
                    tier: .abyss,
                    price: "$16/mo",
                    features: ["Unlimited docs", "Unlimited courses", "100 MB files"],
                    isCurrent: currentTier == .abyss
                )
            }
        }
    }

    private func planCard(
        tier: Tier,
        price: String,
        features: [String],
        isCurrent: Bool
    ) -> some View {
        let colors = theme.colors
        let accentColor: Color = tier == .abyss ? ReefColors.abyss : ReefColors.primary

        return VStack(alignment: .leading, spacing: 10) {
            Text(tier.rawValue.capitalized)
                .font(.epilogue(15, weight: .black))
                .tracking(-0.04 * 15)
                .foregroundStyle(isCurrent ? accentColor : colors.text)

            Text(price)
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(colors.text)

            Divider()
                .background(colors.divider)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text(feature)
                            .font(.epilogue(11, weight: .medium))
                            .tracking(-0.04 * 11)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
            }

            if !isCurrent {
                ReefButton("Upgrade", variant: .primary, size: .compact) {
                    // TODO: link to Stripe
                }
                .padding(.top, 4)
            } else {
                Text("Current Plan")
                    .font(.epilogue(11, weight: .bold))
                    .tracking(-0.04 * 11)
                    .foregroundStyle(accentColor)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? accentColor.opacity(0.06) : colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrent ? accentColor : colors.border, lineWidth: isCurrent ? 2 : 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colors.shadow)
                .offset(x: 3, y: 3)
        )
        .compositingGroup()
    }

    // MARK: - Danger Zone Cell

    private func dangerZoneContent(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Danger Zone")
                .padding(.bottom, 14)
            signOutRow(colors)
            SettingsDivider()
            deleteAccountRow(colors)
        }
    }

    private func signOutRow(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15))
                .foregroundStyle(colors.textSecondary)
                .frame(width: 22)

            Text("Sign Out")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.text)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { showSignOutConfirm = true }
        .accessibilityAddTraits(.isButton)
    }

    private func deleteAccountRow(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.minus")
                .font(.system(size: 15))
                .foregroundStyle(ReefColors.destructive)
                .frame(width: 22)

            Text("Delete Account")
                .font(.epilogue(14, weight: .semiBold))
                .tracking(-0.04 * 14)
                .foregroundStyle(ReefColors.destructive)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.textDisabled)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDeleteConfirm = true }
        .accessibilityAddTraits(.isButton)
    }
}
