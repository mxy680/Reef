import SwiftUI
import PencilKit

@Observable
@MainActor
final class HandwritingTranscriptionService {
    var latexResult: String = ""
    var isTranscribing: Bool = false
    var errorMessage: String?

    private var debounceTask: Task<Void, Never>?
    private var generation: Int = 0

    func onDrawingChanged(drawing: PKDrawing) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await self.transcribe(drawing: drawing)
        }
    }

    func transcribeImmediately(drawing: PKDrawing) {
        debounceTask?.cancel()
        Task { await transcribe(drawing: drawing) }
    }

    func reset() {
        debounceTask?.cancel()
        latexResult = ""
        errorMessage = nil
        isTranscribing = false
    }

    private func transcribe(drawing: PKDrawing) async {
        guard !drawing.strokes.isEmpty else {
            latexResult = ""
            return
        }

        generation += 1
        let myGeneration = generation
        isTranscribing = true
        errorMessage = nil

        do {
            // Render drawing to PNG — crop to bounds with padding
            let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
            let scale: CGFloat = bounds.width > 1500 || bounds.height > 1500 ? 1.0 : 2.0
            let image = drawing.image(from: bounds, scale: scale)

            guard let pngData = image.pngData() else {
                errorMessage = "Failed to render drawing"
                isTranscribing = false
                return
            }

            let base64 = pngData.base64EncodedString()

            // Send to server
            guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
                  let url = URL(string: "\(serverURL)/ai/transcribe-handwriting") else {
                errorMessage = "Server not configured"
                isTranscribing = false
                return
            }

            // Get auth token
            let session = try await supabase.auth.session

            struct RequestBody: Encodable {
                let image_base64: String
            }
            struct ResponseBody: Decodable {
                let latex: String
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(RequestBody(image_base64: base64))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(ResponseBody.self, from: data)

            // Only update if this is still the latest generation
            guard myGeneration == generation else { return }
            latexResult = result.latex
            print("[Transcription] Got LaTeX: \(result.latex.prefix(100))...")
        } catch {
            guard myGeneration == generation else { return }
            print("[Transcription] Failed: \(error)")
            errorMessage = "Transcription failed"
        }

        isTranscribing = false
    }
}
