import SwiftUI
@preconcurrency import Supabase

struct BugReportPopup: View {
    let documentId: String
    let questionLabel: String?
    let onDismiss: () -> Void

    @State private var description: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Report a Bug")
                    .font(.epilogue(17, weight: .black))
                    .tracking(-0.04 * 17)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }

            if showSuccess {
                // Success state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: 0x81C784))
                    Text("Bug report submitted. Thanks!")
                        .font(.epilogue(14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Description input
                Text("Describe what happened:")
                    .font(.epilogue(13, weight: .bold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $description)
                    .font(.system(size: 14))
                    .frame(height: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                // Context info
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Question: \(questionLabel ?? "N/A")")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)

                // Submit button
                Button {
                    submit()
                } label: {
                    HStack(spacing: 6) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                                .tint(.white)
                        }
                        Text(isSending ? "Sending..." : "Submit")
                            .font(.epilogue(14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.gray : Color.black)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
        }
        .padding(24)
        .popupShell()
    }

    private func submit() {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true

        Task {
            do {
                try await sendBugReport(description: text)
                withAnimation(.spring(duration: 0.3)) {
                    showSuccess = true
                }
                // Auto-dismiss after 1.5s
                try? await Task.sleep(for: .seconds(1.5))
                onDismiss()
            } catch {
                isSending = false
            }
        }
    }

    private func sendBugReport(description: String) async throws {
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
              let url = URL(string: "\(serverURL)/api/bug-report") else {
            throw URLError(.badURL)
        }

        let authSession = try await supabase.auth.session

        struct ReportBody: Encodable {
            let description: String
            let document_id: String?
            let question_label: String?
        }

        let body = ReportBody(
            description: description,
            document_id: documentId,
            question_label: questionLabel
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
