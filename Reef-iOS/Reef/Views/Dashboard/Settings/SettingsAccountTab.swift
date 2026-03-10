import SwiftUI

// MARK: - Account Tab

extension SettingsView {
    var accountTab: some View {
        let dark = theme.isDarkMode
        let tier: Tier = .shore
        let limits = TierLimits.current()

        return VStack(spacing: 16) {
            // Row 1: Your Plan | Security
            SettingsRow {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Your Plan")

                        Text("Shore")
                            .font(.epilogue(13, weight: .bold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ReefColors.accent)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5))
                            .padding(.bottom, 16)

                        usageBar(label: "Documents", current: 0, max: limits.maxDocuments)
                            .padding(.bottom, 12)

                        usageBar(label: "Courses", current: 0, max: limits.maxCourses)
                            .padding(.bottom, 12)

                        SettingsDivider()

                        HStack {
                            Text("Max File Size")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                            Spacer()
                            Text("\(limits.maxFileSizeMB) MB")
                                .font(.epilogue(13, weight: .bold))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                        }

                        Button {
                            showToast("Upgrades coming soon!")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle")
                                Text("Upgrade Plan")
                            }
                        }
                        .reefCompactStyle(.primary)
                        .padding(.top, 16)
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionHeader("Security")

                        SettingsFieldLabel("Sign-in Method")
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 13))
                                .foregroundStyle(ReefColors.primary)
                            Text("Magic Link")
                                .font(.epilogue(14, weight: .semiBold))
                                .tracking(-0.04 * 14)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                        }
                        Text(authManager.session?.user.email ?? "—")
                            .font(.epilogue(12, weight: .medium))
                            .tracking(-0.04 * 12)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            .padding(.top, 2)

                        SettingsDivider()

                        SettingsFieldLabel("Two-Factor Authentication")
                        HStack(spacing: 8) {
                            Circle()
                                .fill(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400)
                                .frame(width: 8, height: 8)
                            Text("Not enabled")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
                            Spacer()
                            Button("Enable") {}
                                .reefCompactStyle(.secondary)
                        }

                        SettingsDivider()

                        SettingsFieldLabel("Active Sessions")
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: 0x4CAF50))
                                .frame(width: 8, height: 8)
                            Text("This device — Active now")
                                .font(.epilogue(13, weight: .medium))
                                .tracking(-0.04 * 13)
                                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                        }
                    }
                }
            }

            // Row 2: Compare Plans (full width)
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader("Compare Plans")

                    HStack(spacing: 12) {
                        planColumn(name: "Shore", price: "Free", color: ReefColors.accent, docs: "5", fileSize: "20 MB", courses: "1", isCurrent: tier == .shore)
                        planColumn(name: "Reef", price: "$9.99/mo", color: ReefColors.primary, docs: "50", fileSize: "50 MB", courses: "5", isCurrent: tier == .reef)
                        planColumn(name: "Abyss", price: "$29.99/mo", color: Color(hex: 0x6C3FA0), docs: "Unlimited", fileSize: "100 MB", courses: "Unlimited", isCurrent: tier == .abyss)
                    }
                }
            }

            // Row 3: Actions (full width)
            SettingsCard {
                HStack(spacing: 12) {
                    Button {
                        Task { await authManager.signOut() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .reefCompactStyle(.secondary)

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                        .font(.epilogue(12, weight: .bold))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(Color(hex: 0xC62828))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: 0xE57373), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(NoHighlightButtonStyle())

                    Spacer()
                }
            }
        }
    }

    func usageBar(label: String, current: Int, max limit: Int) -> some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)
                Spacer()
                Text("\(current) / \(limit)")
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
            }

            GeometryReader { geo in
                let pct = limit > 0 ? CGFloat(current) / CGFloat(limit) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(dark ? ReefColors.DashboardDark.subtle : ReefColors.gray100)
                    Capsule()
                        .fill(ReefColors.primary)
                        .frame(width: max(geo.size.width * pct, 0))
                        .animation(.easeOut(duration: 0.6), value: appeared)
                }
            }
            .frame(height: 8)
        }
    }

    func planColumn(name: String, price: String, color: Color, docs: String, fileSize: String, courses: String, isCurrent: Bool) -> some View {
        let dark = theme.isDarkMode
        return VStack(spacing: 12) {
            if isCurrent {
                Text("Current")
                    .font(.epilogue(10, weight: .bold))
                    .tracking(0.06 * 10)
                    .textCase(.uppercase)
                    .foregroundStyle(ReefColors.primary)
            }

            Text(name)
                .font(.epilogue(18, weight: .black))
                .tracking(-0.04 * 18)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            Text(price)
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

            SettingsDivider()

            planFeature(label: "Documents", value: docs)
            planFeature(label: "File Size", value: fileSize)
            planFeature(label: "Courses", value: courses)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(dark ? ReefColors.DashboardDark.card : ReefColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? ReefColors.primary : (dark ? ReefColors.DashboardDark.divider : ReefColors.gray200), lineWidth: isCurrent ? 2 : 1.5)
        )
    }

    func planFeature(label: String, value: String) -> some View {
        let dark = theme.isDarkMode
        return VStack(spacing: 2) {
            Text(value)
                .font(.epilogue(14, weight: .bold))
                .tracking(-0.04 * 14)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
            Text(label)
                .font(.epilogue(11, weight: .medium))
                .tracking(-0.04 * 11)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
        }
    }
}
