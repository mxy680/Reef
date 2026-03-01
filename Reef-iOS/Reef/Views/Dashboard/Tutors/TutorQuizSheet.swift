import SwiftUI

struct TutorQuizPopup: View {
    let tutors: [Tutor]
    let onSelectTutor: (Tutor) -> Void
    let onDismiss: () -> Void

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
    private let scoring: [[[Int]]] = [
        // Q1: "Step-by-step guidance" vs "Explore on my own"
        [
            [3, 2, 0, 1],
            [0, 1, 3, 2],
        ],
        // Q2: "Calm & steady" vs "High energy"
        [
            [2, 3, 1, 0],
            [0, 0, 2, 3],
        ],
        // Q3: "Structured & organized" vs "Exploratory & curious"
        [
            [2, 3, 0, 1],
            [1, 0, 3, 2],
        ],
    ]

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
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { onDismiss() }

            // Popup card
            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ReefColors.gray500)
                            .frame(width: 28, height: 28)
                            .background(ReefColors.gray100)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

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
            .padding(24)
            .background(ReefColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ReefColors.black, lineWidth: 1.5)
            )
            .frame(maxWidth: 420)
            .padding(32)
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: step, total: 3)

            Text(questions[step].text)
                .font(.epilogue(22, weight: .black))
                .tracking(-0.04 * 22)
                .foregroundStyle(ReefColors.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(Array(questions[step].options.enumerated()), id: \.offset) { idx, option in
                    OnboardingOptionButton(
                        label: option,
                        isSelected: answers[step] == idx,
                        action: { answers[step] = idx }
                    )
                }
            }
            .padding(.bottom, 24)

            HStack {
                if step > 0 {
                    Button {
                        direction = .leading
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Back")
                            .font(.epilogue(14, weight: .semiBold))
                            .tracking(-0.04 * 14)
                            .foregroundStyle(ReefColors.gray600)
                    }
                }

                Spacer()

                Button {
                    direction = .trailing
                    withAnimation { step += 1 }
                } label: {
                    Text("Continue")
                }
                .reefStyle(.primary)
                .frame(maxWidth: 160)
                .disabled(answers[step] == nil)
                .opacity(answers[step] != nil ? 1 : 0.5)
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 14) {
            if let tutor = resultTutor {
                let tintColor = Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)

                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(tintColor.opacity(0.3), lineWidth: 2)
                        )

                    Text(tutor.emoji)
                        .font(.system(size: 48))
                }

                Text("Your match: \(tutor.name)!")
                    .font(.epilogue(22, weight: .black))
                    .tracking(-0.04 * 22)
                    .foregroundStyle(ReefColors.black)

                Text(tutor.teachingStyle)
                    .font(.epilogue(13, weight: .medium))
                    .tracking(-0.04 * 13)
                    .foregroundStyle(ReefColors.gray600)
                    .multilineTextAlignment(.center)

                Button {
                    onSelectTutor(tutor)
                } label: {
                    Text("Select \(tutor.name)")
                }
                .reefStyle(.primary)
                .frame(maxWidth: 220)
                .padding(.top, 4)

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
        }
    }
}
