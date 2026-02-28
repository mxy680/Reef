//
//  AdminDashboardView.swift
//  Reef
//
//  Admin dashboard: user management, AI cost tracking, reasoning analytics.
//

import SwiftUI

struct AdminDashboardView: View {
    let colorScheme: ColorScheme
    let userIdentifier: String

    @State private var overview: AdminOverview?
    @State private var users: [AdminUserRow] = []
    @State private var usersTotal: Int = 0
    @State private var costs: AdminCostResponse?
    @State private var reasoning: AdminReasoningStats?
    @State private var userSearch: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var cardBackground: Color {
        colorScheme == .dark ? Color.warmDarkCard : .cardBackground
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.deepCoral)
                    Text(error)
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        overviewCards
                        userListSection
                        costBreakdownSection
                        reasoningStatsSection
                    }
                    .padding(32)
                }
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .task {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.fill")
                .font(.system(size: 24))
                .foregroundColor(.deepTeal)
            Text("Admin Dashboard")
                .font(.dynaPuff(28, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
            Spacer()
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        HStack(spacing: 16) {
            BentoStatCard(
                icon: "person.2.fill",
                iconColor: .deepTeal,
                value: "\(overview?.total_users ?? 0)",
                label: "users",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "doc.fill",
                iconColor: .deepCoral,
                value: "\(overview?.total_documents ?? 0)",
                label: "documents",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "brain.head.profile",
                iconColor: .deepTeal,
                value: "\(overview?.total_reasoning_calls ?? 0)",
                label: "AI calls",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "dollarsign.circle.fill",
                iconColor: .deepCoral,
                value: String(format: "$%.2f", overview?.total_cost ?? 0),
                label: "total cost",
                colorScheme: colorScheme
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - User List

    private var userListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Users", color: .deepTeal)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                TextField("Search users...", text: $userSearch)
                    .font(.quicksand(15, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .onSubmit {
                        Task { await searchUsers() }
                    }
            }
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // User rows
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Email")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Last Active")
                        .frame(width: 120, alignment: .leading)
                    Text("Sessions")
                        .frame(width: 80, alignment: .trailing)
                    Text("AI Calls")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.quicksand(13, weight: .semiBold))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(users) { user in
                    HStack {
                        Text(user.display_name ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(user.email ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatDate(user.last_active))
                            .frame(width: 120, alignment: .leading)
                        Text("\(user.session_count)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(user.reasoning_calls)")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 16)
                }

                if users.isEmpty {
                    Text("No users found")
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .padding(20)
                }
            }
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    // MARK: - Cost Breakdown

    private var costBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Cost Breakdown (30 days)", color: .deepCoral)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Date")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Calls")
                        .frame(width: 80, alignment: .trailing)
                    Text("Prompt Tk")
                        .frame(width: 100, alignment: .trailing)
                    Text("Compl Tk")
                        .frame(width: 100, alignment: .trailing)
                    Text("Cost")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.quicksand(13, weight: .semiBold))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(costs?.rows ?? []) { row in
                    HStack {
                        Text(row.date)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.calls)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(row.prompt_tokens)")
                            .frame(width: 100, alignment: .trailing)
                        Text("\(row.completion_tokens)")
                            .frame(width: 100, alignment: .trailing)
                        Text(String(format: "$%.3f", row.cost))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider().padding(.leading, 16)
                }

                // Totals row
                if let costs = costs {
                    HStack {
                        Text("Total")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(costs.total_calls)")
                            .frame(width: 80, alignment: .trailing)
                        Spacer().frame(width: 100)
                        Spacer().frame(width: 100)
                        Text(String(format: "$%.2f", costs.total_cost))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.quicksand(14, weight: .bold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        colorScheme == .dark
                            ? Color.deepTeal.opacity(0.08)
                            : Color.seafoam.opacity(0.3)
                    )
                }
            }
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    // MARK: - Reasoning Stats

    private var reasoningStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Reasoning Analytics", color: .deepTeal)

            HStack(spacing: 16) {
                // Left: Speak/Silent ratio + error count
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        statPill(label: "Speak", value: "\(reasoning?.speak_count ?? 0)", color: .deepCoral)
                        statPill(label: "Silent", value: "\(reasoning?.silent_count ?? 0)", color: .deepTeal)
                        statPill(label: "Errors", value: "\(reasoning?.error_count ?? 0)", color: .red)
                    }

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg Prompt Tokens")
                                .font(.quicksand(12, weight: .medium))
                                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                            Text(String(format: "%.0f", reasoning?.avg_prompt_tokens ?? 0))
                                .font(.quicksand(20, weight: .bold))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg Completion Tokens")
                                .font(.quicksand(12, weight: .medium))
                                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                            Text(String(format: "%.0f", reasoning?.avg_completion_tokens ?? 0))
                                .font(.quicksand(20, weight: .bold))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                        }
                    }
                }

                Spacer()

                // Right: By source breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Source")
                        .font(.quicksand(14, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))

                    ForEach(Array(reasoning?.by_source.sorted(by: { $0.value > $1.value }) ?? []), id: \.key) { source, count in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.deepTeal)
                                .frame(width: 6, height: 6)
                            Text(source)
                                .font(.quicksand(14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                            Spacer()
                            Text("\(count)")
                                .font(.quicksand(14, weight: .semiBold))
                                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        }
                    }
                }
                .frame(width: 200)
            }
            .padding(20)
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.quicksand(18, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.quicksand(22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.quicksand(12, weight: .medium))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(colorScheme == .dark ? 0.12 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "—" }
        // Show just the date portion
        return String(dateString.prefix(10))
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let overviewResult = AdminService.shared.fetchOverview(userIdentifier: userIdentifier)
            async let usersResult = AdminService.shared.fetchUsers(userIdentifier: userIdentifier)
            async let costsResult = AdminService.shared.fetchCosts(userIdentifier: userIdentifier)
            async let reasoningResult = AdminService.shared.fetchReasoningStats(userIdentifier: userIdentifier)

            overview = try await overviewResult
            let userList = try await usersResult
            users = userList.users
            usersTotal = userList.total
            costs = try await costsResult
            reasoning = try await reasoningResult
        } catch {
            errorMessage = "Failed to load admin data"
        }

        isLoading = false
    }

    private func searchUsers() async {
        do {
            let result = try await AdminService.shared.fetchUsers(
                userIdentifier: userIdentifier,
                search: userSearch
            )
            users = result.users
            usersTotal = result.total
        } catch {
            // Keep existing data on search failure
        }
    }
}
