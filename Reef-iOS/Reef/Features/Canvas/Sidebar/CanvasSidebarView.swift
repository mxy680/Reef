import SwiftUI

struct CanvasSidebarView: View {
    @Environment(ReefTheme.self) private var theme
    var isDarkMode: Bool
    @Bindable var viewModel: CanvasViewModel

    var body: some View {
        let colors = ReefThemeColors(isDarkMode: isDarkMode)

        HStack(spacing: 0) {
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.2))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                // Collapsible Hint/Answer Panels
                if viewModel.tutorModeOn, viewModel.currentHintStep != nil {
                    hintAnswerSection(colors: colors)
                }

                Rectangle()
                    .fill(colors.divider)
                    .frame(height: 1)

                // Tutor section
                tutorSection(colors: colors)
                    .frame(maxHeight: .infinity)
            }
            .background(isDarkMode ? ReefColors.CanvasDark.background : Color(hex: 0xF8F0E6))
        }
        .frame(width: 260)
    }

    // MARK: - Hint / Answer Section

    @ViewBuilder
    private func hintAnswerSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsiblePanel(
                title: "Hint",
                icon: "lightbulb.fill",
                isExpanded: viewModel.showHintPanel,
                accentColor: Color(hex: 0xF5A623),
                colors: colors
            ) {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.showHintPanel.toggle()
                }
            } content: {
                if let step = viewModel.currentHintStep {
                    Text(step.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(colors.text)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }

            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            collapsiblePanel(
                title: "Full Solution",
                icon: "eye.fill",
                isExpanded: viewModel.showSolutionPanel,
                accentColor: ReefColors.primary,
                colors: colors
            ) {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.showSolutionPanel.toggle()
                }
            } content: {
                if let step = viewModel.currentHintStep {
                    ScrollView {
                        Text(step.work)
                            .font(.system(size: 13))
                            .foregroundStyle(colors.text)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.25), value: viewModel.showHintPanel)
        .animation(.spring(duration: 0.25), value: viewModel.showSolutionPanel)
    }

    @ViewBuilder
    private func collapsiblePanel(
        title: String,
        icon: String,
        isExpanded: Bool,
        accentColor: Color,
        colors: ReefThemeColors,
        toggle: @escaping () -> Void,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReefColors.primary)
                        .frame(width: 16, alignment: .center)
                    Text(title)
                        .font(.epilogue(13, weight: .black))
                        .tracking(-0.04 * 13)
                        .foregroundStyle(colors.text)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(colors.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }

    // MARK: - Tutor Section

    @ViewBuilder
    private func tutorSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ReefColors.primary)
                    .frame(width: 16, alignment: .center)
                Text("Tutor")
                    .font(.epilogue(13, weight: .black))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(colors.text)
                Spacer()
                Text("idle")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            // Empty chat placeholder
            Spacer()
            VStack(spacing: 8) {
                Text("Your work and feedback will\nappear here")
                    .font(.epilogue(12, weight: .medium))
                    .foregroundStyle(colors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer()

            // Chat input stub
            Rectangle()
                .fill(colors.divider)
                .frame(height: 0.5)

            HStack(spacing: 8) {
                Text("Ask the tutor...")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
