import SwiftUI

// MARK: - CalculatorView

struct CalculatorView: View {
    @Environment(ReefTheme.self) private var theme
    @Bindable var viewModel: CalculatorViewModel

    var isDarkMode: Bool
    var onClose: () -> Void

    // MARK: - Drag State

    @State private var position: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    // MARK: - Layout Constants

    private var cardWidth: CGFloat { viewModel.isCompact ? 280 : 380 }
    private let buttonSpacing: CGFloat = 6
    private let buttonHeight: CGFloat = 44
    private let cornerRadius: CGFloat = 16
    private let borderWidth: CGFloat = 2
    private let shadowOffset: CGFloat = 4

    // MARK: - Body

    var body: some View {
        let colors = theme.colors

        VStack(spacing: 0) {
            titleBar(colors: colors)
            displayArea(colors: colors)

            if viewModel.isShowingHistory {
                historyPanel(colors: colors)
            }

            buttonGrid
                .padding(10)
        }
        .frame(width: cardWidth)
        .background(colors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(colors.border, lineWidth: borderWidth)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colors.shadow)
                .offset(x: shadowOffset, y: shadowOffset)
        )
        .compositingGroup()
        .offset(x: position.width + dragOffset.width, y: position.height + dragOffset.height)
        .animation(.spring(duration: 0.25, bounce: 0.1), value: viewModel.isCompact)
    }

    // MARK: - Title Bar

    private func titleBar(colors: ReefThemeColors) -> some View {
        HStack(spacing: 8) {
            Text("Calculator")
                .font(.epilogue(14, weight: .black))
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.isCompact.toggle()
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(colors.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(NoHighlightButtonStyle())

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.isShowingHistory.toggle()
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.isShowingHistory ? ReefColors.primary : colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(viewModel.isShowingHistory ? ReefColors.primary.opacity(0.15) : colors.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(NoHighlightButtonStyle())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(colors.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(NoHighlightButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    position = CGSize(
                        width: position.width + value.translation.width,
                        height: position.height + value.translation.height
                    )
                    dragOffset = .zero
                }
        )
    }

    // MARK: - Display Area

    private func displayArea(colors: ReefThemeColors) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(viewModel.displayText.isEmpty ? "0" : viewModel.displayText)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .flipsForRightToLeftLayoutDirection(true)

            Text(viewModel.resultText.isEmpty ? " " : viewModel.resultText)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(colors.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - History Panel

    private func historyPanel(colors: ReefThemeColors) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(colors.divider)

            CalculatorHistoryView(
                history: viewModel.history,
                onSelect: { entry in
                    viewModel.displayText = entry.result
                    withAnimation(.spring(duration: 0.2)) {
                        viewModel.isShowingHistory = false
                    }
                },
                onClear: {
                    // history is private(set) — call through the ViewModel
                    viewModel.clearHistory()
                }
            )

            Divider()
                .background(colors.divider)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Button Grid

    @ViewBuilder
    private var buttonGrid: some View {
        if viewModel.isCompact {
            compactGrid
        } else {
            expandedGrid
        }
    }

    // MARK: - Compact Grid (4 × 5)

    private var compactGrid: some View {
        Grid(horizontalSpacing: buttonSpacing, verticalSpacing: buttonSpacing) {
            // Row 1: AC, +/-, %, ÷
            GridRow {
                calcButton("AC", style: .action) { viewModel.allClear() }
                calcButton("+/-", style: .function) { viewModel.toggleSign() }
                calcButton("%", style: .function) { viewModel.appendCharacter("%") }
                calcButton("÷", style: .operation) { viewModel.appendCharacter("/") }
            }
            // Row 2: 7, 8, 9, ×
            GridRow {
                calcButton("7", style: .number) { viewModel.appendCharacter("7") }
                calcButton("8", style: .number) { viewModel.appendCharacter("8") }
                calcButton("9", style: .number) { viewModel.appendCharacter("9") }
                calcButton("×", style: .operation) { viewModel.appendCharacter("*") }
            }
            // Row 3: 4, 5, 6, −
            GridRow {
                calcButton("4", style: .number) { viewModel.appendCharacter("4") }
                calcButton("5", style: .number) { viewModel.appendCharacter("5") }
                calcButton("6", style: .number) { viewModel.appendCharacter("6") }
                calcButton("−", style: .operation) { viewModel.appendCharacter("-") }
            }
            // Row 4: 1, 2, 3, +
            GridRow {
                calcButton("1", style: .number) { viewModel.appendCharacter("1") }
                calcButton("2", style: .number) { viewModel.appendCharacter("2") }
                calcButton("3", style: .number) { viewModel.appendCharacter("3") }
                calcButton("+", style: .operation) { viewModel.appendCharacter("+") }
            }
            // Row 5: 0 (spans 2 columns), ., =
            GridRow {
                calcButton("0", style: .number) { viewModel.appendCharacter("0") }
                    .gridCellColumns(2)
                calcButton(".", style: .number) { viewModel.appendCharacter(".") }
                calcButton("=", style: .equals) { viewModel.evaluate() }
            }
        }
        .environment(theme)
    }

    // MARK: - Expanded Grid (6 × 6)

    private var expandedGrid: some View {
        Grid(horizontalSpacing: buttonSpacing, verticalSpacing: buttonSpacing) {
            // Extra top row: (, ), x^y, π, e, !
            GridRow {
                calcButton("(", style: .function) { viewModel.appendCharacter("(") }
                calcButton(")", style: .function) { viewModel.appendCharacter(")") }
                calcButton("xʸ", style: .function) { viewModel.appendCharacter("^") }
                calcButton("π", style: .function) { viewModel.appendCharacter("pi") }
                calcButton("e", style: .function) { viewModel.appendCharacter("e") }
                calcButton("!", style: .function) { viewModel.appendCharacter("!") }
            }
            // Row 1: sin, cos, AC, +/-, %, ÷
            GridRow {
                calcButton("sin", style: .function) { viewModel.appendFunction("sin") }
                calcButton("cos", style: .function) { viewModel.appendFunction("cos") }
                calcButton("AC", style: .action) { viewModel.allClear() }
                calcButton("+/-", style: .function) { viewModel.toggleSign() }
                calcButton("%", style: .function) { viewModel.appendCharacter("%") }
                calcButton("÷", style: .operation) { viewModel.appendCharacter("/") }
            }
            // Row 2: tan, ln, 7, 8, 9, ×
            GridRow {
                calcButton("tan", style: .function) { viewModel.appendFunction("tan") }
                calcButton("ln", style: .function) { viewModel.appendFunction("ln") }
                calcButton("7", style: .number) { viewModel.appendCharacter("7") }
                calcButton("8", style: .number) { viewModel.appendCharacter("8") }
                calcButton("9", style: .number) { viewModel.appendCharacter("9") }
                calcButton("×", style: .operation) { viewModel.appendCharacter("*") }
            }
            // Row 3: √, log, 4, 5, 6, −
            GridRow {
                calcButton("√", style: .function) { viewModel.appendFunction("sqrt") }
                calcButton("log", style: .function) { viewModel.appendFunction("log") }
                calcButton("4", style: .number) { viewModel.appendCharacter("4") }
                calcButton("5", style: .number) { viewModel.appendCharacter("5") }
                calcButton("6", style: .number) { viewModel.appendCharacter("6") }
                calcButton("−", style: .operation) { viewModel.appendCharacter("-") }
            }
            // Row 4: ⌫, abs, 1, 2, 3, +
            GridRow {
                calcButton("⌫", style: .function) { viewModel.deleteLastCharacter() }
                calcButton("abs", style: .function) { viewModel.appendFunction("abs") }
                calcButton("1", style: .number) { viewModel.appendCharacter("1") }
                calcButton("2", style: .number) { viewModel.appendCharacter("2") }
                calcButton("3", style: .number) { viewModel.appendCharacter("3") }
                calcButton("+", style: .operation) { viewModel.appendCharacter("+") }
            }
            // Row 5: 0 (spans 3 of 6 equal columns), ., =
            GridRow {
                calcButton("0", style: .number) { viewModel.appendCharacter("0") }
                    .gridCellColumns(3)
                calcButton(".", style: .number) { viewModel.appendCharacter(".") }
                calcButton("=", style: .equals) { viewModel.evaluate() }
                    .gridCellColumns(2)
            }
        }
        .environment(theme)
    }

    // MARK: - Cell Helper

    @ViewBuilder
    private func calcButton(
        _ label: String,
        icon: String? = nil,
        style: CalcButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        CalculatorButton(label: label, icon: icon, style: style, action: action)
            .frame(height: buttonHeight)
            .frame(maxWidth: .infinity)
            .environment(theme)
    }
}
