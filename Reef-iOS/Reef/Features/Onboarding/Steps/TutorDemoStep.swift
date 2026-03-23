import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme
    @Environment(\.reefLayoutMetrics) private var metrics

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?

    var body: some View {
        ZStack {
            if let canvasVM {
                // Full canvas experience
                CanvasView(viewModel: canvasVM, onDismiss: {
                    viewModel.goNext()
                })

                // Floating "Done" button — bottom-left overlay
                VStack {
                    Spacer()
                    HStack {
                        ReefButton("Done — show me my plan", size: .compact, action: {
                            viewModel.goNext()
                        })
                        .padding(20)
                        Spacer()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(200)
            } else {
                loadingCard
            }
        }
        .onAppear {
            if !demoService.isReady && !demoService.isGenerating {
                Task {
                    await demoService.generateDocument(
                        topic: viewModel.answers.favoriteTopic,
                        studentType: viewModel.answers.studentType?.rawValue ?? "college"
                    )
                    if let doc = demoService.demoDocument {
                        canvasVM = CanvasViewModel(document: doc)
                    }
                }
            }
        }
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        let colors = theme.colors

        return GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Try it out")
                        .font(.epilogue(28, weight: .black))
                        .tracking(-0.04 * 28)
                        .foregroundStyle(colors.text)
                        .fadeUp(index: 0)

                    if demoService.isGenerating {
                        generatingView
                    } else if let errorMessage = demoService.error {
                        errorView(message: errorMessage, colors: colors)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(colors.border, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.shadow)
                        .offset(x: 5, y: 5)
                )
                .frame(maxWidth: metrics.onboardingCardMaxWidth)
                .padding(.horizontal, metrics.authHPadding)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Subviews

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ReefColors.primary)
            Text("Cooking up a problem...")
                .font(.epilogue(14, weight: .medium))
                .tracking(-0.04 * 14)
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .fadeUp(index: 1)
    }

    private func errorView(message: String, colors: ReefThemeColors) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't generate a problem")
                .font(.epilogue(15, weight: .bold))
                .tracking(-0.04 * 15)
                .foregroundStyle(colors.text)

            Text(message)
                .font(.epilogue(12, weight: .medium))
                .tracking(-0.04 * 12)
                .foregroundStyle(colors.textMuted)

            ReefButton("Try again", size: .compact, action: {
                Task {
                    await demoService.generateDocument(
                        topic: viewModel.answers.favoriteTopic,
                        studentType: viewModel.answers.studentType?.rawValue ?? "college"
                    )
                    if let doc = demoService.demoDocument {
                        canvasVM = CanvasViewModel(document: doc)
                    }
                }
            })
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .fadeUp(index: 1)
    }
}
