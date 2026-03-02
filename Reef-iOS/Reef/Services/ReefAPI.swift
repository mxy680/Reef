import Foundation

actor ReefAPI {
    static let shared = ReefAPI()

    private let baseURL: URL
    private var wsTask: URLSessionWebSocketTask?
    private var isConnected = false

    private init() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "REEF_SERVER_URL") as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Missing REEF_SERVER_URL in Info.plist — check Secrets.xcconfig")
        }
        self.baseURL = url
    }

    // MARK: - Access Token

    private func getAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }

    // MARK: - REST

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await getAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode
        else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - WebSocket

    func connectWebSocket() async throws {
        let token = try await getAccessToken()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ws"),
            resolvingAgainstBaseURL: false
        )!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        let session = URLSession(configuration: .default)
        wsTask = session.webSocketTask(with: components.url!)
        wsTask?.resume()
        isConnected = true

        Task { await receiveLoop() }
    }

    func disconnectWebSocket() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
    }

    func sendMessage(_ message: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8)!
        try await wsTask?.send(.string(string))
    }

    private func receiveLoop() async {
        guard let ws = wsTask else { return }
        do {
            while isConnected {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    print("[ReefAPI] Received: \(text)")
                case .data(let data):
                    print("[ReefAPI] Received binary: \(data.count) bytes")
                @unknown default:
                    break
                }
            }
        } catch {
            isConnected = false
        }
    }
}
