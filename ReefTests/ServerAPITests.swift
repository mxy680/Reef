//
//  ServerAPITests.swift
//  ReefTests
//
//  Integration tests for Reef-Server REST API endpoints.
//  Requires the Reef-Server running at http://localhost:8000.
//  Tests hit the server directly via URLSession — not through AIService.
//

import Testing
import Foundation
@testable import Reef

@Suite("Server API Integration", .serialized)
struct ServerAPITests {

    // MARK: - Helpers

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        let url = URL(string: "\(IntegrationTestConfig.baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    private func jsonResponse(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - B2: Stroke Logging

    @Test("stroke connect and disconnect lifecycle")
    func strokeConnectAndDisconnectLifecycle() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()

        let (connectData, connectResponse) = try await makeRequest(
            path: "/api/strokes/connect",
            method: "POST",
            body: [
                "session_id": sessionId,
                "user_id": "test-user",
                "document_name": "test-doc",
                "question_number": NSNull()
            ]
        )
        #expect(connectResponse.statusCode == 200)
        let connectJSON = jsonResponse(connectData)
        #expect(connectJSON?["status"] as? String == "connected")

        let (disconnectData, disconnectResponse) = try await makeRequest(
            path: "/api/strokes/disconnect",
            method: "POST",
            body: ["session_id": sessionId]
        )
        #expect(disconnectResponse.statusCode == 200)
        let disconnectJSON = jsonResponse(disconnectData)
        #expect(disconnectJSON?["status"] as? String == "disconnected")
    }

    @Test("log strokes returns ok")
    func logStrokesReturnsOk() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()
        defer { Task { await cleanupTestSession(sessionId: sessionId) } }

        _ = try await makeRequest(
            path: "/api/strokes/connect",
            method: "POST",
            body: [
                "session_id": sessionId,
                "user_id": "test-user",
                "document_name": "test-doc",
                "question_number": NSNull()
            ]
        )

        let strokePoints: [[[String: Double]]] = [
            [["x": 0, "y": 0], ["x": 1, "y": 1]]
        ]
        let (data, response) = try await makeRequest(
            path: "/api/strokes",
            method: "POST",
            body: [
                "session_id": sessionId,
                "page": 1,
                "strokes": strokePoints,
                "event_type": "draw",
                "deleted_count": 0
            ]
        )
        #expect(response.statusCode == 200)
        let json = jsonResponse(data)
        #expect(json?["status"] as? String == "ok")
    }

    @Test("log strokes with empty strokes array")
    func logStrokesWithEmptyStrokesArray() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()
        defer { Task { await cleanupTestSession(sessionId: sessionId) } }

        _ = try await makeRequest(
            path: "/api/strokes/connect",
            method: "POST",
            body: [
                "session_id": sessionId,
                "user_id": "test-user",
                "document_name": "test-doc",
                "question_number": NSNull()
            ]
        )

        let (data, response) = try await makeRequest(
            path: "/api/strokes",
            method: "POST",
            body: [
                "session_id": sessionId,
                "page": 1,
                "strokes": [] as [[Any]],
                "event_type": "draw",
                "deleted_count": 0
            ]
        )
        #expect(response.statusCode == 200)
        let json = jsonResponse(data)
        #expect(json?["status"] as? String == "ok")
    }

    @Test("clear strokes returns ok")
    func clearStrokesReturnsOk() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()
        defer { Task { await cleanupTestSession(sessionId: sessionId) } }

        _ = try await makeRequest(
            path: "/api/strokes/connect",
            method: "POST",
            body: [
                "session_id": sessionId,
                "user_id": "test-user",
                "document_name": "test-doc",
                "question_number": NSNull()
            ]
        )

        let (data, response) = try await makeRequest(
            path: "/api/strokes/clear",
            method: "POST",
            body: [
                "session_id": sessionId,
                "page": 1
            ]
        )
        #expect(response.statusCode == 200)
        let json = jsonResponse(data)
        #expect(json?["status"] as? String == "ok")
    }

    // MARK: - B3: SSE Events

    @Test("SSE connection established")
    func sseConnectionEstablished() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()
        let url = URL(string: "\(IntegrationTestConfig.baseURL)/api/events?session_id=\(sessionId)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        // Verify we can open the SSE stream and it returns text/event-stream
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                #expect(httpResponse.statusCode == 200)
                let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
                #expect(contentType.contains("text/event-stream"))
            }
        }
        task.resume()

        // Give the connection a moment to establish, then cancel
        try await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()
    }

    // MARK: - B6: Profile

    @Test("create and get profile round-trip")
    func createAndGetProfileRoundTrip() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let testUserId = UUID().uuidString
        let authHeader = ["Authorization": "Bearer \(testUserId)"]

        // Create profile
        let (putData, putResponse) = try await makeRequest(
            path: "/users/profile",
            method: "PUT",
            body: [
                "display_name": "Test User",
                "email": "test@example.com"
            ],
            headers: authHeader
        )
        #expect(putResponse.statusCode == 200)
        let putJSON = jsonResponse(putData)
        #expect(putJSON != nil)

        // Get profile and verify round-trip
        let (getData, getResponse) = try await makeRequest(
            path: "/users/profile",
            method: "GET",
            headers: authHeader
        )
        #expect(getResponse.statusCode == 200)
        let getJSON = jsonResponse(getData)
        #expect(getJSON?["display_name"] as? String == "Test User")
        #expect(getJSON?["email"] as? String == "test@example.com")

        // Clean up
        _ = try await makeRequest(
            path: "/users/profile",
            method: "DELETE",
            headers: authHeader
        )
    }

    @Test("get profile for unknown user returns 404")
    func getProfileForUnknownUserReturns404() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let unknownUserId = UUID().uuidString
        let (_, response) = try await makeRequest(
            path: "/users/profile",
            method: "GET",
            headers: ["Authorization": "Bearer \(unknownUserId)"]
        )
        #expect(response.statusCode == 404)
    }

    // MARK: - B8: Session Management

    @Test("delete stroke logs for session")
    func deleteStrokeLogsForSession() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let sessionId = makeTestSessionId()
        defer { Task { await cleanupTestSession(sessionId: sessionId) } }

        // Connect and log some strokes
        _ = try await makeRequest(
            path: "/api/strokes/connect",
            method: "POST",
            body: [
                "session_id": sessionId,
                "user_id": "test-user",
                "document_name": "test-doc",
                "question_number": NSNull()
            ]
        )

        _ = try await makeRequest(
            path: "/api/strokes",
            method: "POST",
            body: [
                "session_id": sessionId,
                "page": 1,
                "strokes": [
                    [["x": 0, "y": 0], ["x": 10, "y": 10]]
                ] as [[[String: Double]]],
                "event_type": "draw",
                "deleted_count": 0
            ]
        )

        // Delete stroke logs
        let (data, response) = try await makeRequest(
            path: "/api/stroke-logs?session_id=\(sessionId)",
            method: "DELETE"
        )
        #expect(response.statusCode == 200)
        let json = jsonResponse(data)
        // Server returns {"deleted": <count>}
        if let deletedCount = json?["deleted"] as? Int {
            #expect(deletedCount >= 0)
        }
    }
}
