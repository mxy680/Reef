//
//  GeminiService.swift
//  Reef
//
//  Actor-based service for interacting with Google's Gemini API
//  Supports both direct API calls and proxy through Reef Server
//

import Foundation

/// Actor-based service for Gemini API interactions
actor GeminiService {
    static let shared = GeminiService()

    // MARK: - Configuration

    /// API mode determines how requests are routed
    enum APIMode {
        /// Call Gemini API directly (requires API key in client)
        case direct
        /// Proxy through Reef Server (API key stored server-side)
        case server
    }

    /// Server mode for testing
    enum ServerMode: String {
        case prod
        case mock
    }

    private let apiKey: String
    private let directBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.5-flash"

    /// The current API mode
    private(set) var apiMode: APIMode

    /// Server URL when using server mode
    private let serverURL: String

    /// Server mode (prod or mock) - only used when apiMode is .server
    var serverMode: ServerMode = .prod

    private init() {
        self.apiKey = Secrets.geminiAPIKey

        // Configure based on build settings
        #if DEBUG
        // In debug, use server proxy with local URL by default
        // Change to .direct to test direct API calls
        self.apiMode = .server
        self.serverURL = ProcessInfo.processInfo.environment["REEF_SERVER_URL"]
            ?? "http://localhost:8000"
        #else
        // In release, use production server
        self.apiMode = .server
        self.serverURL = ProcessInfo.processInfo.environment["REEF_SERVER_URL"]
            ?? "https://reef-server.vercel.app"
        #endif
    }

    /// Configure the API mode at runtime
    func configure(mode: APIMode, serverURL: String? = nil) {
        self.apiMode = mode
        // serverURL is set at init and not changed
    }

    // MARK: - Request/Response Types (Direct API)

    struct GeminiRequest: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig?

        struct Content: Encodable {
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String?
            let inlineData: InlineData?

            init(text: String) {
                self.text = text
                self.inlineData = nil
            }

            init(inlineData: InlineData) {
                self.text = nil
                self.inlineData = inlineData
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let text = text {
                    try container.encode(text, forKey: .text)
                }
                if let inlineData = inlineData {
                    try container.encode(inlineData, forKey: .inlineData)
                }
            }

            private enum CodingKeys: String, CodingKey {
                case text
                case inlineData = "inline_data"
            }
        }

        struct InlineData: Encodable {
            let mimeType: String
            let data: String  // base64 encoded

            private enum CodingKeys: String, CodingKey {
                case mimeType = "mime_type"
                case data
            }
        }

        struct GenerationConfig: Encodable {
            let responseMimeType: String?
            let responseSchema: JSONSchema?
            let temperature: Double?
            let maxOutputTokens: Int?
        }
    }

    /// JSON Schema for structured outputs (uses class to allow recursive definitions)
    final class JSONSchema: Encodable {
        let type: String
        let properties: [String: JSONSchema]?
        let items: JSONSchema?
        let required: [String]?
        let `enum`: [String]?
        let description: String?

        init(
            type: String,
            properties: [String: JSONSchema]? = nil,
            items: JSONSchema? = nil,
            required: [String]? = nil,
            enumValues: [String]? = nil,
            description: String? = nil
        ) {
            self.type = type
            self.properties = properties
            self.items = items
            self.required = required
            self.`enum` = enumValues
            self.description = description
        }

        /// Convenience for string type
        static var string: JSONSchema { JSONSchema(type: "string") }

        /// Convenience for integer type
        static var integer: JSONSchema { JSONSchema(type: "integer") }

        /// Convenience for number type (floating point)
        static var number: JSONSchema { JSONSchema(type: "number") }

        /// Convenience for array of items
        static func array(of items: JSONSchema) -> JSONSchema {
            JSONSchema(type: "array", items: items)
        }

        /// Convenience for enum strings
        static func `enum`(_ values: [String]) -> JSONSchema {
            JSONSchema(type: "string", enumValues: values)
        }

        /// Convenience for object with properties
        static func object(_ properties: [String: JSONSchema], required: [String]? = nil) -> JSONSchema {
            JSONSchema(type: "object", properties: properties, required: required)
        }

        /// Convert to dictionary for server requests
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = ["type": type]
            if let properties = properties {
                dict["properties"] = properties.mapValues { $0.toDictionary() }
            }
            if let items = items {
                dict["items"] = items.toDictionary()
            }
            if let required = required {
                dict["required"] = required
            }
            if let enumValues = `enum` {
                dict["enum"] = enumValues
            }
            if let description = description {
                dict["description"] = description
            }
            return dict
        }
    }

    struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        let error: GeminiError?

        struct Candidate: Decodable {
            let content: Content
        }

        struct Content: Decodable {
            let parts: [Part]
        }

        struct Part: Decodable {
            let text: String
        }

        struct GeminiError: Decodable {
            let message: String
        }
    }

    // MARK: - Request/Response Types (Server Proxy)

    private struct ServerGenerateRequest: Encodable {
        let prompt: String
        let json_output: Bool
        let response_schema: [String: Any]?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(prompt, forKey: .prompt)
            try container.encode(json_output, forKey: .json_output)
            if let schema = response_schema {
                let jsonData = try JSONSerialization.data(withJSONObject: schema)
                let jsonObject = try JSONDecoder().decode(AnyCodable.self, from: jsonData)
                try container.encode(jsonObject, forKey: .response_schema)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case prompt
            case json_output
            case response_schema
        }
    }

    private struct ServerVisionRequest: Encodable {
        let prompt: String
        let images: [[String: String]]
        let json_output: Bool
        let response_schema: [String: Any]?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(prompt, forKey: .prompt)
            try container.encode(images, forKey: .images)
            try container.encode(json_output, forKey: .json_output)
            if let schema = response_schema {
                let jsonData = try JSONSerialization.data(withJSONObject: schema)
                let jsonObject = try JSONDecoder().decode(AnyCodable.self, from: jsonData)
                try container.encode(jsonObject, forKey: .response_schema)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case prompt
            case images
            case json_output
            case response_schema
        }
    }

    private struct ServerResponse: Decodable {
        let text: String
        let model: String?
        let mode: String?
    }

    // MARK: - Public API

    /// Generate content using Gemini
    /// - Parameters:
    ///   - prompt: The prompt to send to Gemini
    ///   - jsonOutput: If true, request JSON output format with temperature 0
    ///   - schema: Optional JSON schema for structured outputs
    /// - Returns: The generated text response
    func generateContent(prompt: String, jsonOutput: Bool = false, schema: JSONSchema? = nil) async throws -> String {
        switch apiMode {
        case .direct:
            return try await generateContentDirect(prompt: prompt, jsonOutput: jsonOutput, schema: schema)
        case .server:
            return try await generateContentViaServer(prompt: prompt, jsonOutput: jsonOutput, schema: schema)
        }
    }

    /// Generate content using Gemini with images (multimodal)
    /// - Parameters:
    ///   - prompt: The prompt to send to Gemini
    ///   - images: Array of image data with MIME types
    ///   - jsonOutput: If true, request JSON output format with temperature 0
    ///   - schema: Optional JSON schema for structured outputs
    /// - Returns: The generated text response
    func generateContentWithImages(
        prompt: String,
        images: [(data: Data, mimeType: String)],
        jsonOutput: Bool = false,
        schema: JSONSchema? = nil
    ) async throws -> String {
        switch apiMode {
        case .direct:
            return try await generateContentWithImagesDirect(prompt: prompt, images: images, jsonOutput: jsonOutput, schema: schema)
        case .server:
            return try await generateContentWithImagesViaServer(prompt: prompt, images: images, jsonOutput: jsonOutput, schema: schema)
        }
    }

    // MARK: - Direct API Implementation

    private func generateContentDirect(prompt: String, jsonOutput: Bool, schema: JSONSchema?) async throws -> String {
        guard let url = URL(string: "\(directBaseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let generationConfig: GeminiRequest.GenerationConfig?
        if let schema = schema {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: schema, temperature: 0, maxOutputTokens: 16384)
        } else if jsonOutput {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: nil, temperature: 0, maxOutputTokens: 16384)
        } else {
            generationConfig = nil
        }

        let geminiRequest = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: generationConfig
        )

        request.httpBody = try JSONEncoder().encode(geminiRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let errorMessage = errorResponse.error?.message {
                throw GeminiError.apiError(errorMessage)
            }
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw GeminiError.apiError(error.message)
        }

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }

        return text
    }

    private func generateContentWithImagesDirect(
        prompt: String,
        images: [(data: Data, mimeType: String)],
        jsonOutput: Bool,
        schema: JSONSchema?
    ) async throws -> String {
        guard let url = URL(string: "\(directBaseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build parts array with images first, then text prompt
        var parts: [GeminiRequest.Part] = images.map { imageData in
            GeminiRequest.Part(inlineData: GeminiRequest.InlineData(
                mimeType: imageData.mimeType,
                data: imageData.data.base64EncodedString()
            ))
        }
        parts.append(GeminiRequest.Part(text: prompt))

        let generationConfig: GeminiRequest.GenerationConfig?
        if let schema = schema {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: schema, temperature: 0, maxOutputTokens: 16384)
        } else if jsonOutput {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: nil, temperature: 0, maxOutputTokens: 16384)
        } else {
            generationConfig = nil
        }

        let geminiRequest = GeminiRequest(
            contents: [.init(parts: parts)],
            generationConfig: generationConfig
        )

        request.httpBody = try JSONEncoder().encode(geminiRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let errorMessage = errorResponse.error?.message {
                throw GeminiError.apiError(errorMessage)
            }
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw GeminiError.apiError(error.message)
        }

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }

        return text
    }

    // MARK: - Server Proxy Implementation

    private func generateContentViaServer(prompt: String, jsonOutput: Bool, schema: JSONSchema?) async throws -> String {
        guard let url = URL(string: "\(serverURL)/gemini/generate?mode=\(serverMode.rawValue)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let serverRequest = ServerGenerateRequest(
            prompt: prompt,
            json_output: jsonOutput,
            response_schema: schema?.toDictionary()
        )

        request.httpBody = try JSONEncoder().encode(serverRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
        return serverResponse.text
    }

    private func generateContentWithImagesViaServer(
        prompt: String,
        images: [(data: Data, mimeType: String)],
        jsonOutput: Bool,
        schema: JSONSchema?
    ) async throws -> String {
        guard let url = URL(string: "\(serverURL)/gemini/vision?mode=\(serverMode.rawValue)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let imagesDicts = images.map { imageData in
            ["data": imageData.data.base64EncodedString(), "mime_type": imageData.mimeType]
        }

        let serverRequest = ServerVisionRequest(
            prompt: prompt,
            images: imagesDicts,
            json_output: jsonOutput,
            response_schema: schema?.toDictionary()
        )

        request.httpBody = try JSONEncoder().encode(serverRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
        return serverResponse.text
    }

    // MARK: - Errors

    enum GeminiError: Error, LocalizedError {
        case invalidURL
        case requestFailed
        case httpError(Int)
        case apiError(String)
        case noContent

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Gemini API URL"
            case .requestFailed:
                return "Gemini API request failed"
            case .httpError(let code):
                return "Gemini API returned HTTP \(code)"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            case .noContent:
                return "Gemini API returned no content"
            }
        }
    }
}

// MARK: - Helper for encoding arbitrary dictionaries

private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode value"))
        }
    }
}
