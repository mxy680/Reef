import SwiftUI

struct GenerateQuestionPopup: View {
    @Environment(ReefTheme.self) private var theme
    let onGenerate: (Document) -> Void
    let onClose: () -> Void

    @State private var service = GenerateQuestionService()
    @State private var subject = "math"
    @State private var topic = ""
    @State private var difficulty: Double = 3
    @State private var numSteps: Double = 3

    private let subjects: [(id: String, label: String, icon: String)] = [
        ("math", "Math", "function"),
        ("physics", "Physics", "atom"),
        ("chemistry", "Chemistry", "flask.fill"),
        ("biology", "Biology", "leaf"),
        ("economics", "Economics", "chart.line.uptrend.xyaxis"),
        ("computer_science", "CS", "laptopcomputer"),
    ]

    private let difficultyLabels = ["", "Easy", "Quiz", "Midterm", "Final", "Competition"]

    private var isTopicEmpty: Bool {
        topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let colors = theme.colors
        VStack(alignment: .leading, spacing: 16) {
            headerRow(colors: colors)

            subjectSection(colors: colors)

            topicSection(colors: colors)

            difficultySection(colors: colors)

            stepsSection(colors: colors)

            if let error = service.error {
                Text(error)
                    .font(.epilogue(11, weight: .medium))
                    .foregroundStyle(.red)
            }

            generateButton
        }
        .padding(20)
        .popupShell()
    }

    // MARK: - Subviews

    private func headerRow(colors: ReefThemeColors) -> some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(colors.text)
            Text("Generate Question")
                .font(.epilogue(18, weight: .bold))
                .tracking(-0.04 * 18)
                .foregroundStyle(colors.text)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private func subjectSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subject")
                .font(.epilogue(12, weight: .semiBold))
                .foregroundStyle(colors.textMuted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(subjects, id: \.id) { item in
                    Button(action: { subject = item.id }) {
                        HStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11))
                            Text(item.label)
                                .font(.epilogue(11, weight: .semiBold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(subject == item.id ? ReefColors.primary : colors.card)
                        .foregroundStyle(subject == item.id ? .white : colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func topicSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.epilogue(12, weight: .semiBold))
                .foregroundStyle(colors.textMuted)

            TextField("e.g. integration by parts", text: $topic)
                .font(.epilogue(14, weight: .medium))
                .padding(10)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.border, lineWidth: 1)
                )
        }
    }

    private func difficultySection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Difficulty")
                    .font(.epilogue(12, weight: .semiBold))
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text(difficultyLabels[Int(difficulty)])
                    .font(.epilogue(12, weight: .bold))
                    .foregroundStyle(ReefColors.primary)
            }
            Slider(value: $difficulty, in: 1...5, step: 1)
                .tint(ReefColors.primary)
        }
    }

    private func stepsSection(colors: ReefThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Steps")
                    .font(.epilogue(12, weight: .semiBold))
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text("\(Int(numSteps))")
                    .font(.epilogue(12, weight: .bold))
                    .foregroundStyle(ReefColors.primary)
            }
            Slider(value: $numSteps, in: 2...6, step: 1)
                .tint(ReefColors.primary)
        }
    }

    private var generateButton: some View {
        ReefButton(
            service.isGenerating ? "Generating..." : "Generate",
            variant: .primary,
            size: .compact,
            disabled: isTopicEmpty || service.isGenerating,
            action: {
                Task {
                    await service.generate(
                        subject: subject,
                        topic: topic,
                        difficulty: Int(difficulty),
                        numSteps: Int(numSteps)
                    )
                    if let doc = service.generatedDocument {
                        onGenerate(doc)
                    }
                }
            }
        )
        .frame(maxWidth: .infinity)
    }
}
