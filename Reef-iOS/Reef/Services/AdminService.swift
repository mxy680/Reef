//
//  AdminService.swift
//  Reef
//
//  Networking service for admin dashboard endpoints on Reef-Server.
//

import Foundation

// MARK: - Response Models

struct AdminOverview: Codable {
    let total_users: Int
    let total_documents: Int
    let total_reasoning_calls: Int
    let total_cost: Double
    let speak_count: Int
    let silent_count: Int
    let active_sessions: Int
}

struct AdminUserRow: Codable, Identifiable {
    let apple_user_id: String
    let display_name: String?
    let email: String?
    let created_at: String?
    let last_active: String?
    let session_count: Int
    let reasoning_calls: Int

    var id: String { apple_user_id }
}

struct AdminUserListResponse: Codable {
    let users: [AdminUserRow]
    let total: Int
}

struct DailyCostRow: Codable, Identifiable {
    let date: String
    let calls: Int
    let prompt_tokens: Int
    let completion_tokens: Int
    let cost: Double

    var id: String { date }
}

struct AdminCostResponse: Codable {
    let rows: [DailyCostRow]
    let total_cost: Double
    let total_calls: Int
}

struct AdminReasoningStats: Codable {
    let total_calls: Int
    let speak_count: Int
    let silent_count: Int
    let error_count: Int
    let avg_prompt_tokens: Double
    let avg_completion_tokens: Double
    let by_source: [String: Int]
}

// MARK: - AdminService

@MainActor
class AdminService {
    static let shared = AdminService()

    private let baseURL = ServerConfig.baseURL
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func fetchOverview(userIdentifier: String) async throws -> AdminOverview {
        let data = try await get(path: "/api/admin/overview", userIdentifier: userIdentifier)
        return try JSONDecoder().decode(AdminOverview.self, from: data)
    }

    func fetchUsers(userIdentifier: String, search: String = "", limit: Int = 50, offset: Int = 0) async throws -> AdminUserListResponse {
        var query = "limit=\(limit)&offset=\(offset)"
        if !search.isEmpty {
            query += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        let data = try await get(path: "/api/admin/users?\(query)", userIdentifier: userIdentifier)
        return try JSONDecoder().decode(AdminUserListResponse.self, from: data)
    }

    func fetchCosts(userIdentifier: String, days: Int = 30) async throws -> AdminCostResponse {
        let data = try await get(path: "/api/admin/costs?days=\(days)", userIdentifier: userIdentifier)
        return try JSONDecoder().decode(AdminCostResponse.self, from: data)
    }

    func fetchReasoningStats(userIdentifier: String) async throws -> AdminReasoningStats {
        let data = try await get(path: "/api/admin/reasoning", userIdentifier: userIdentifier)
        return try JSONDecoder().decode(AdminReasoningStats.self, from: data)
    }

    // MARK: - Private

    private func get(path: String, userIdentifier: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userIdentifier)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}
