//
//  TutorStepRow.swift
//  Reef
//

import SwiftUI

// MARK: - Tutor Step Row (inline in info strip)

struct TutorStepRow: View {
    let questionIndex: Int
    var activePartLabel: String? = nil
    let answerKey: QuestionAnswer?
    var stepProgressData: [String: StepProgress]? = nil
    var currentStepIndex: Int = 0
    var totalStepCount: Int = 0
    var onMistakeTapped: () -> Void = {}
    @Binding var mistakeIconMidX: CGFloat

    private var steps: [TutorStep] {
        guard let answerKey else { return [] }
        return TutorStepConverter.steps(from: answerKey, progress: stepProgressData, questionIndex: questionIndex)
    }

    private var currentStep: TutorStep? {
        steps.first(where: { $0.status != .completed }) ?? steps.last
    }

    var body: some View {
        if currentStep != nil {
            HStack(spacing: 0) {
                stepDivider()

                // Q label + Step indicator
                HStack(spacing: 6) {
                    statusIcon(for: currentStep!.status)
                        .padding(6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if currentStep!.status == .mistake {
                                onMistakeTapped()
                            }
                        }
                        .background(GeometryReader { geo in
                            Color.clear
                                .onChange(of: currentStep?.status) { _, _ in
                                    mistakeIconMidX = geo.frame(in: .global).midX
                                }
                                .onAppear {
                                    mistakeIconMidX = geo.frame(in: .global).midX
                                }
                        })

                    Text({
                        let base = "Q\(questionIndex + 1)"
                        if let label = activePartLabel {
                            return "\(base) (\(label))"
                        }
                        return base
                    }())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    if totalStepCount > 0 {
                        Text("Step \(min(currentStepIndex + 1, totalStepCount))/\(totalStepCount)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                stepDivider()

                // Instruction text
                Text(currentStep!.instruction)
                    .font(.epilogue(12, weight: .medium))
                    .tracking(-0.04 * 12)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(.white.opacity(0.7))
                    .scaleEffect(0.65)
                Text("Loading...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Icon

    private static let barColor = Color(hex: 0x4E8A97)

    @ViewBuilder
    private func statusIcon(for status: StepStatus) -> some View {
        switch status {
        case .idle:
            statusIcon3D(bgColor: Self.barColor) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
            }
        case .working:
            statusIcon3D(bgColor: Self.barColor) {
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        case .mistake:
            statusIcon3D(bgColor: Color(hex: 0xE57373)) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white)
            }
        case .completed:
            statusIcon3D(bgColor: Color(hex: 0x81C784)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white)
            }
        }
    }

    private func statusIcon3D<Content: View>(bgColor: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 16, height: 16)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.8))
                    .offset(x: 1.5, y: 1.5)
            )
    }

    // MARK: - Divider

    private func stepDivider() -> some View {
        Text("|")
            .font(.system(size: 20, weight: .ultraLight))
            .foregroundColor(.white.opacity(0.4))
            .frame(width: 16)
    }
}
