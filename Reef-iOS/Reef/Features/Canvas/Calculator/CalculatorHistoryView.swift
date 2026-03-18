import SwiftUI

// MARK: - CalculatorHistoryView

struct CalculatorHistoryView: View {
    @Environment(ReefTheme.self) private var theme

    let history: [CalculatorHistoryEntry]
    let onSelect: (CalculatorHistoryEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            if history.isEmpty {
                emptyState(colors: colors)
            } else {
                historyList(colors: colors)
                clearButton(colors: colors)
            }
        }
        .frame(maxHeight: 200)
    }

    // MARK: - Empty State

    private func emptyState(colors: ReefThemeColors) -> some View {
        Text("No calculations yet")
            .font(.epilogue(13, weight: .medium))
            .foregroundStyle(colors.textMuted)
            .frame(maxWidth: .infinity, minHeight: 60)
    }

    // MARK: - History List

    private func historyList(colors: ReefThemeColors) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(history) { entry in
                    historyRow(entry: entry, colors: colors)

                    if entry.id != history.last?.id {
                        Divider()
                            .background(colors.divider)
                    }
                }
            }
        }
    }

    // MARK: - History Row

    private func historyRow(entry: CalculatorHistoryEntry, colors: ReefThemeColors) -> some View {
        Button {
            onSelect(entry)
        } label: {
            HStack(alignment: .center) {
                Text(entry.expression)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.result)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
                    .frame(alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
    }

    // MARK: - Clear Button

    private func clearButton(colors: ReefThemeColors) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(colors.divider)

            Button(action: onClear) {
                Text("Clear History")
                    .font(.epilogue(13, weight: .bold))
                    .foregroundStyle(ReefColors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(NoHighlightButtonStyle())
        }
    }
}
