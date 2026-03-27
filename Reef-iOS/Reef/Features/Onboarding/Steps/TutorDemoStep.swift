import SwiftUI

struct TutorDemoStep: View {
    @Environment(ReefTheme.self) private var theme

    @Bindable var viewModel: OnboardingViewModel
    @State private var demoService = DemoProblemService()
    @State private var canvasVM: CanvasViewModel?

    var body: some View {
        ZStack {
            if let canvasVM {
                CanvasView(viewModel: canvasVM, onDismiss: {
                    Task { await viewModel.deleteDemoDocument() }
                    viewModel.goNext()
                })
            } else {
                loadingView
            }
        }
        .onAppear { generateDemo() }
    }

    private func generateDemo() {
        guard !demoService.isReady && !demoService.isGenerating else { return }
        Task {
            let topic = viewModel.answers.favoriteTopic.isEmpty
                ? "derivatives"
                : viewModel.answers.favoriteTopic
            await demoService.generateDocument(
                topic: topic,
                studentType: viewModel.answers.studentType?.rawValue ?? "college"
            )
            if let doc = demoService.demoDocument {
                viewModel.demoDocumentId = doc.id
                let vm = CanvasViewModel(document: doc)
                vm.tutorEvalService.isDemo = true
                canvasVM = vm
            }
        }
    }

    private var loadingView: some View {
        let colors = theme.colors
        return VStack(spacing: 20) {
            if demoService.isGenerating {
                ProgressView()
                    .tint(colors.text)
                Text("Generating a problem for you...")
                    .font(.epilogue(16, weight: .medium))
                    .foregroundStyle(colors.textMuted)
            } else if let error = demoService.error {
                Text(error)
                    .font(.epilogue(14, weight: .medium))
                    .foregroundStyle(colors.textMuted)
                ReefButton("Try again", size: .compact, action: {
                    demoService.error = nil
                    generateDemo()
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
