import SwiftUI

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index <= current ? ReefColors.primary : ReefColors.white)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(ReefColors.black, lineWidth: 2)
                    )
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
        .padding(.bottom, 28)
    }
}

// MARK: - Option Button (single-select rows for Grade / Referral)

struct OnboardingOptionButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(isSelected ? ReefColors.white : ReefColors.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(isSelected ? ReefColors.primary : ReefColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ReefColors.black, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ReefColors.black)
                        .offset(
                            x: isPressed ? 0 : (isSelected ? 3 : 4),
                            y: isPressed ? 0 : (isSelected ? 3 : 4)
                        )
                )
                .offset(
                    x: isPressed ? (isSelected ? 3 : 4) : 0,
                    y: isPressed ? (isSelected ? 3 : 4) : 0
                )
                .animation(.spring(duration: 0.3, bounce: 0.2), value: isPressed)
                .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Subject Pill (multi-select pills for Subjects)

struct SubjectPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.epilogue(13, weight: .semiBold))
                .tracking(-0.04 * 13)
                .foregroundStyle(isSelected ? ReefColors.white : ReefColors.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ReefColors.primary : ReefColors.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(ReefColors.black, lineWidth: 2)
                )
                .background(
                    Capsule()
                        .fill(ReefColors.black)
                        .offset(
                            x: isPressed ? 0 : 3,
                            y: isPressed ? 0 : 3
                        )
                )
                .offset(
                    x: isPressed ? 3 : 0,
                    y: isPressed ? 3 : 0
                )
                .animation(.spring(duration: 0.3, bounce: 0.2), value: isPressed)
                .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Onboarding navigation footer (Back + Continue/Submit)

struct OnboardingNavigation: View {
    let backLabel: String?
    let forwardLabel: String
    let canAdvance: Bool
    var isSubmitting: Bool = false
    let onBack: (() -> Void)?
    let onForward: () -> Void

    var body: some View {
        HStack {
            if let backLabel, let onBack {
                Button(action: onBack) {
                    Text(backLabel)
                        .font(.epilogue(14, weight: .semiBold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.gray600)
                }
                .disabled(isSubmitting)
            }

            Spacer()

            Button(action: onForward) {
                Text(isSubmitting ? "Saving..." : forwardLabel)
            }
            .reefStyle(canAdvance ? .primary : .secondary)
            .frame(maxWidth: 160)
            .disabled(!canAdvance || isSubmitting)
            .opacity(canAdvance ? 1 : 0.7)
        }
    }
}
