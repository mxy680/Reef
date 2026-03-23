import Foundation

@Observable
@MainActor
final class DemoProblemService {

    // MARK: - State

    var isGenerating = false
    var isReady = false
    var error: String?
    var demoDocument: Document?

    // MARK: - Server URL

    private var serverURL: String {
        Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String ?? ""
    }

    // MARK: - Generate Document

    func generateDocument(topic: String, studentType: String = "college") async {
        guard !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isGenerating = true
        error = nil

        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/ai/demo-document") else {
            error = "Server not configured."
            isGenerating = false
            return
        }

        guard let token = try? await supabase.auth.session.accessToken else {
            error = "Not authenticated"
            isGenerating = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60  // LLM + LaTeX compilation + upload takes time

        let body: [String: String] = [
            "topic": topic,
            "student_type": studentType,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw NSError(
                    domain: "DemoError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned \(statusCode)"]
                )
            }

            let result = try JSONDecoder().decode(DemoDocumentResponse.self, from: data)
            let userId = (try? await supabase.auth.session.user.id.uuidString) ?? ""

            demoDocument = Document(
                id: result.documentId,
                userId: userId,
                filename: result.filename,
                status: .completed,
                pageCount: result.pageCount,
                problemCount: result.problemCount,
                questionPages: [[0, 0]],
                questionRegions: nil,
                errorMessage: nil,
                statusMessage: nil,
                costCents: nil,
                courseId: nil,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )

            isReady = true
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }
}

// MARK: - Response DTO

private struct DemoDocumentResponse: Codable {
    let documentId: String
    let filename: String
    let pageCount: Int
    let problemCount: Int

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case filename
        case pageCount = "page_count"
        case problemCount = "problem_count"
    }
}
