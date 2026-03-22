import SwiftUI

struct PainPointsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepShell(
            title: "What trips you up the most?",
            subtitle: "Be real. No judgment — we've seen it all.",
            canAdvance: viewModel.canAdvance,
            onBack: { viewModel.goBack() },
            onForward: { viewModel.goNext() }
        ) {
            VStack(spacing: 10) {
                ForEach(PainPoint.allCases, id: \.self) { point in
                    OnboardingOption(
                        label: point.displayLabel,
                        isSelected: viewModel.answers.painPoints.contains(point),
                        action: {
                            if viewModel.answers.painPoints.contains(point) {
                                viewModel.answers.painPoints.remove(point)
                            } else {
                                viewModel.answers.painPoints.insert(point)
                            }
                        }
                    )
                }
            }
        }
    }
}
