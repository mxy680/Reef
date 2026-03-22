import SwiftUI

// MARK: - Sample Data

private struct SubjectData: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let mastery: Int
    let hours: Double
}

private struct SessionData: Identifiable {
    let id = UUID()
    let subject: String
    let date: String
    let duration: String
    let pages: Int
}

private let subjects: [SubjectData] = [
    .init(name: "Calculus II", color: Color(hex: 0x5B9EAD), mastery: 78, hours: 4.5),
    .init(name: "Organic Chemistry", color: Color(hex: 0xE07A5F), mastery: 62, hours: 3.2),
    .init(name: "Linear Algebra", color: Color(hex: 0x81B29A), mastery: 91, hours: 2.8),
    .init(name: "Physics II", color: Color(hex: 0xF2CC8F), mastery: 45, hours: 1.5),
]

private let weeklyMinutes = [65, 42, 88, 0, 55, 72, 38]
private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

private let recentSessions: [SessionData] = [
    .init(subject: "Calculus II", date: "Feb 28", duration: "45 min", pages: 3),
    .init(subject: "Organic Chemistry", date: "Feb 27", duration: "32 min", pages: 2),
    .init(subject: "Linear Algebra", date: "Feb 27", duration: "28 min", pages: 4),
    .init(subject: "Calculus II", date: "Feb 26", duration: "55 min", pages: 5),
    .init(subject: "Physics II", date: "Feb 25", duration: "18 min", pages: 1),
]

private struct StatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private let statItems: [StatItem] = [
    .init(label: "Total Study Time", value: "12.0 hrs"),
    .init(label: "Sessions This Week", value: "18"),
    .init(label: "Avg. Mastery", value: "69%"),
    .init(label: "Study Streak", value: "5 days"),
]

// MARK: - Analytics View

struct AnalyticsView: View {
    @State private var appeared = false
    @Environment(\.reefLayoutMetrics) private var metrics
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                headerSection(colors)
                statCardsRow(colors)
                chartRowTop
                chartRowBottom
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.contentPadding)
        .dashboardCard()
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private func headerSection(_ colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Study Analytics")
                .font(.epilogue(24, weight: .black))
                .tracking(-0.04 * 24)
                .foregroundStyle(colors.text)

            Text("Track your progress, study time, and subject mastery over time.")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(colors.textSecondary)

            Text("Preview — data shown is for demonstration purposes only.")
                .font(.epilogue(11, weight: .medium))
                .tracking(-0.04 * 11)
                .foregroundStyle(colors.textMuted)
                .italic()
        }
        .padding(.horizontal, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.1), value: appeared)
    }

    // MARK: - Stat Cards

    private func statCardsRow(_ colors: ReefThemeColors) -> some View {
        HStack(spacing: metrics.sectionSpacing) {
            ForEach(Array(statItems.enumerated()), id: \.element.id) { index, stat in
                statCard(stat, colors: colors, index: index)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statCard(_ stat: StatItem, colors: ReefThemeColors, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stat.label)
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)

            Text(stat.value)
                .font(.epilogue(26, weight: .bold))
                .tracking(-0.04 * 26)
                .foregroundStyle(colors.text)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, metrics.statCardVPadding)
        .dashboardCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.18 + Double(index) * 0.04), value: appeared)
    }

    // MARK: - Chart Rows

    private var chartRowTop: some View {
        HStack(spacing: metrics.sectionSpacing) {
            WeeklyActivityCard(appeared: appeared, metrics: metrics)
            RecentSessionsCard(appeared: appeared, metrics: metrics)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var chartRowBottom: some View {
        HStack(spacing: metrics.sectionSpacing) {
            TimeBySubjectCard(appeared: appeared, metrics: metrics)
            MasteryBySubjectCard(appeared: appeared, metrics: metrics)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Weekly Activity Bar Chart

private struct WeeklyActivityCard: View {
    let appeared: Bool
    let metrics: ReefLayoutMetrics
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Weekly Activity")
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.text)
                .padding(.bottom, 4)

            Text("Daily study minutes this week")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)

            Spacer(minLength: 0)

            WeeklyBarChart()
                .frame(height: metrics.chartHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.chartCardPadding)
        .dashboardCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.3), value: appeared)
    }
}

private struct WeeklyBarChart: View {
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        let gridLineColor = colors.subtle
        let emptyBarColor = colors.subtle
        let dayLabelColor = colors.textSecondary
        let valueLabelColor = colors.textMuted

        GeometryReader { geo in
            let maxMinutes = weeklyMinutes.max() ?? 1
            let barCount = CGFloat(weeklyMinutes.count)
            let spacing: CGFloat = 10
            let totalSpacing = spacing * (barCount - 1)
            let barWidth = (geo.size.width - totalSpacing) / barCount
            let topInset: CGFloat = 20
            let chartHeight = geo.size.height - 24 - topInset

            Canvas { context, size in
                // Grid lines
                for frac in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    let y = topInset + chartHeight * (1 - frac)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(gridLineColor), lineWidth: 1)
                }

                // Bars
                for (i, minutes) in weeklyMinutes.enumerated() {
                    let barH = maxMinutes > 0 ? (CGFloat(minutes) / CGFloat(maxMinutes)) * chartHeight : 0
                    let x = CGFloat(i) * (barWidth + spacing)
                    let y = topInset + chartHeight - barH
                    let barColor = minutes == 0 ? emptyBarColor : ReefColors.primary

                    let bar = Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: max(barH, 4)), cornerRadius: 5)
                    context.fill(bar, with: .color(barColor))

                    // Day label
                    let label = Text(dayLabels[i])
                        .font(.epilogue(11, weight: .medium))
                        .foregroundStyle(dayLabelColor)
                    context.draw(
                        context.resolve(label),
                        at: CGPoint(x: x + barWidth / 2, y: topInset + chartHeight + 14),
                        anchor: .center
                    )

                    // Value above bar
                    let value = Text("\(minutes)")
                        .font(.epilogue(10, weight: .bold))
                        .foregroundStyle(valueLabelColor)
                    context.draw(
                        context.resolve(value),
                        at: CGPoint(x: x + barWidth / 2, y: y - 8),
                        anchor: .center
                    )
                }
            }
        }
    }
}

// MARK: - Time by Subject

private struct TimeBySubjectCard: View {
    let appeared: Bool
    let metrics: ReefLayoutMetrics
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Time by Subject")
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.text)
                .padding(.bottom, 4)

            Text("Total hours studied")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 20)

            VStack(spacing: 16) {
                ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                    SubjectBarRow(subject: subject, index: index, appeared: appeared)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.chartCardPadding)
        .dashboardCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.35), value: appeared)
    }
}

private struct SubjectBarRow: View {
    let subject: SubjectData
    let index: Int
    let appeared: Bool
    private let maxHours: Double = subjects.map(\.hours).max() ?? 1
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 6) {
            HStack {
                Text(subject.name)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)

                Spacer()

                Text(String(format: "%.1fh", subject.hours))
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textSecondary)
            }

            GeometryReader { geo in
                let pct = maxHours > 0 ? subject.hours / maxHours : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colors.subtle)

                    Capsule()
                        .fill(subject.color)
                        .frame(width: appeared ? geo.size.width * pct : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.45 + Double(index) * 0.08), value: appeared)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Mastery by Subject (Donut Rings)

private struct MasteryBySubjectCard: View {
    let appeared: Bool
    let metrics: ReefLayoutMetrics
    @Environment(ReefTheme.self) private var theme

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Mastery by Subject")
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.text)
                .padding(.bottom, 4)

            Text("Based on session performance")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                    DonutRing(subject: subject, index: index, appeared: appeared)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.chartCardPadding)
        .dashboardCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.4), value: appeared)
    }
}

private struct DonutRing: View {
    let subject: SubjectData
    let index: Int
    let appeared: Bool
    @Environment(ReefTheme.self) private var theme

    private let radius: CGFloat = 32
    private let strokeWidth: CGFloat = 6

    var body: some View {
        let colors = theme.colors
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(colors.subtle, lineWidth: strokeWidth)

                Circle()
                    .trim(from: 0, to: appeared ? CGFloat(subject.mastery) / 100.0 : 0)
                    .stroke(subject.color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7).delay(0.5 + Double(index) * 0.1), value: appeared)

                Text("\(subject.mastery)%")
                    .font(.epilogue(13, weight: .bold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)
            }
            .frame(width: radius * 2 + strokeWidth, height: radius * 2 + strokeWidth)

            Text(subject.name)
                .font(.epilogue(11, weight: .semiBold))
                .tracking(-0.04 * 11)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 80)
        }
    }
}

// MARK: - Recent Sessions

private struct RecentSessionsCard: View {
    let appeared: Bool
    let metrics: ReefLayoutMetrics
    @Environment(ReefTheme.self) private var theme

    private var subjectColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: subjects.map { ($0.name, $0.color) })
    }

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Sessions")
                .font(.epilogue(16, weight: .bold))
                .tracking(-0.04 * 16)
                .foregroundStyle(colors.text)
                .padding(.bottom, 4)

            Text("Your latest study activity")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(colors.textSecondary)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                    sessionRow(session, color: subjectColorMap[session.subject] ?? ReefColors.primary, colors: colors)

                    if index < recentSessions.count - 1 {
                        Rectangle()
                            .fill(colors.divider)
                            .frame(height: 1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(metrics.chartCardPadding)
        .dashboardCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(0.45), value: appeared)
    }

    private func sessionRow(_ session: SessionData, color: Color, colors: ReefThemeColors) -> some View {
        HStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.subject)
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(colors.text)
                        .lineLimit(1)

                    Text(session.date)
                        .font(.epilogue(12, weight: .medium))
                        .tracking(-0.04 * 12)
                        .foregroundStyle(colors.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Text(session.duration)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.textSecondary)

                Text("\(session.pages) \(session.pages == 1 ? "page" : "pages")")
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundStyle(colors.textDisabled)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
    }
}
