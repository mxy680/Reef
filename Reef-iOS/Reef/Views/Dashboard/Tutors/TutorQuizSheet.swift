import SwiftUI

struct TutorQuizSheet: View {
    let tutors: [Tutor]
    let onSelectTutor: (Tutor) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step = 0          // 0-2 = questions, 3 = result
    @State private var direction: Edge = .trailing
    @State private var answers: [Int?] = [nil, nil, nil]

    // MARK: - Questions

    private struct Question {
        let text: String
        let options: [String]
    }

    private let questions: [Question] = [
        Question(
            text: "How do you like to learn?",
            options: ["Step-by-step guidance", "Explore on my own"]
        ),
        Question(
            text: "What energy do you prefer?",
            options: ["Calm & steady", "High energy"]
        ),
        Question(
            text: "What's your style?",
            options: ["Structured & organized", "Exploratory & curious"]
        ),
    ]

    // MARK: - Scoring

    // Each question × each option → points per tutor [Kai, Shelly, Otto, Finn]
    // Q1: step-by-step vs explore
    // Q2: calm vs energetic
    // Q3: structured vs exploratory
    private let scoring: [[[Int]]] = [
        // Q1: "Step-by-step guidance" vs "Explore on my own"
        [
            [3, 2, 0, 1],  // step-by-step → Kai 3, Shelly 2, Otto 0, Finn 1
            [0, 1, 3, 2],  // explore → Otto 3, Finn 2, Shelly 1, Kai 0
        ],
        // Q2: "Calm & steady" vs "High energy"
        [
            [2, 3, 1, 0],  // calm → Shelly 3, Kai 2, Otto 1, Finn 0
            [0, 0, 2, 3],  // energy → Finn 3, Otto 2, Kai 0, Shelly 0
        ],
        // Q3: "Structured & organized" vs "Exploratory & curious"
        [
            [2, 3, 0, 1],  // structured → Shelly 3, Kai 2, Finn 1, Otto 0
            [1, 0, 3, 2],  // exploratory → Otto 3, Finn 2, Kai 1, Shelly 0
        ],
    ]

    // Tutor IDs in scoring order
    private let scoringOrder = ["tutor-kai", "tutor-shelly", "tutor-otto", "tutor-finn"]

    private var resultTutor: Tutor? {
        var totals = [0, 0, 0, 0]
        for (qi, answer) in answers.enumerated() {
            guard let a = answer else { continue }
            let points = scoring[qi][a]
            for i in 0..<4 { totals[i] += points[i] }
        }
        let maxIdx = totals.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let targetId = scoringOrder[maxIdx]
        return tutors.first(where: { $0.id == targetId })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step < 3 {
                    questionView
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: direction).combined(with: .opacity),
                            removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                } else {
                    resultView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(duration: 0.35), value: step)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ReefColors.gray500)
                            .frame(width: 32, height: 32)
                            .background(ReefColors.gray100)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: step, total: 3)

            Text(questions[step].text)
                .font(.epilogue(24, weight: .black))
                .tracking(-0.04 * 24)
                .foregroundStyle(ReefColors.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                ForEach(Array(questions[step].options.enumerated()), id: \.offset) { idx, option in
                    OnboardingOptionButton(
                        label: option,
                        isSelected: answers[step] == idx,
                        action: { answers[step] = idx }
                    )
                }
            }

            Spacer()

            OnboardingNavigation(
                backLabel: step > 0 ? "Back" : nil,
                forwardLabel: "Continue",
                canAdvance: answers[step] != nil,
                onBack: step > 0 ? {
                    direction = .leading
                    withAnimation { step -= 1 }
                } : nil,
                onForward: {
                    direction = .trailing
                    withAnimation { step += 1 }
                }
            )
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let tutor = resultTutor {
                let tintColor = Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)

                // Avatar
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(tintColor.opacity(0.3), lineWidth: 2)
                        )

                    Text(tutor.emoji)
                        .font(.system(size: 56))
                }

                Text("Your match: \(tutor.name)!")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(ReefColors.black)

                Text(tutor.teachingStyle)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray600)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()

                // Select button
                Button {
                    onSelectTutor(tutor)
                    dismiss()
                } label: {
                    Text("Select \(tutor.name)")
                }
                .reefStyle(.primary)
                .frame(maxWidth: 220)

                // Retake
                Button {
                    answers = [nil, nil, nil]
                    direction = .leading
                    withAnimation { step = 0 }
                } label: {
                    Text("Retake Quiz")
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.gray600)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
