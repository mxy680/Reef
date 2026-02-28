//
//  RAGServiceTests.swift
//  ReefTests
//
//  Integration tests for RAGService using the real local dev server,
//  real EmbeddingService, and a real VectorStore backed by a temp SQLite file.
//

import Testing
@testable import Reef
import Foundation

@Suite("RAGService Integration", .serialized)
struct RAGServiceTests {

    // MARK: - Helpers

    /// Build a fresh set of real dependencies backed by a temp SQLite file.
    /// Returns the service, vectorStore, and the temp DB URL so callers can clean up.
    private func makeIntegrationDeps() async throws -> (RAGService, VectorStore, URL) {
        let tempDB = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-test-\(UUID().uuidString).sqlite")
        let aiService = AIService(baseURL: "http://localhost:8000")
        let embeddingService = EmbeddingService(aiService: aiService)
        let vectorStore = VectorStore(dbPath: tempDB)
        try await vectorStore.initialize()
        let ragService = RAGService(embeddingService: embeddingService, vectorStore: vectorStore)
        try await ragService.initialize()
        return (ragService, vectorStore, tempDB)
    }

    private func cleanup(vectorStore: VectorStore, tempDB: URL) async {
        await vectorStore.close()
        try? FileManager.default.removeItem(at: tempDB)
    }

    // MARK: - indexDocument

    @Test("indexDocument chunks and stores in real SQLite")
    func indexDocument_chunksAndStoresInRealSQLite() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        let courseId = UUID()
        // ~600 chars — well above TextChunker.minChunkSize (200)
        let text = String(repeating: "This is sample content for integration testing the RAG pipeline. ", count: 9)

        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: courseId,
            text: text
        )

        let count = await ragService.chunkCount(forDocument: docId)
        #expect(count > 0)
    }

    @Test("indexDocument short text skips indexing")
    func indexDocument_shortText_skipsIndexing() async throws {
        // No server needed — RAGService exits before calling embedding
        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: UUID(),
            text: "too short"
        )

        let count = await ragService.chunkCount(forDocument: docId)
        #expect(count == 0)
    }

    // MARK: - getContext

    @Test("getContext returns formatted prompt with real embeddings")
    func getContext_returnsFormattedPromptWithRealEmbeddings() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        let courseId = UUID()
        let topicText = String(
            repeating: "Calculus derivatives are the rate of change of a function with respect to a variable. ",
            count: 8
        )

        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: courseId,
            text: topicText
        )

        let context = try await ragService.getContext(
            query: "what are derivatives",
            courseId: courseId
        )

        #expect(context.hasContext)
        #expect(context.formattedPrompt.contains("course materials"))
        #expect(context.formattedPrompt.lowercased().contains("derivative"))
    }

    @Test("getContext no results for unrelated query")
    func getContext_noResultsForUnrelatedQuery() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let courseId = UUID()
        let marineText = String(
            repeating: "Marine biology studies ocean ecosystems, coral reefs, and deep-sea creatures. ",
            count: 8
        )

        try await ragService.indexDocument(
            documentId: UUID(),
            documentType: .note,
            courseId: courseId,
            text: marineText
        )

        let context = try await ragService.getContext(
            query: "quantum physics wave-particle duality",
            courseId: courseId
        )

        // RAGService filters results with similarity <= 0.15, so we either get
        // no context or very low similarity chunks that were filtered out.
        if context.hasContext {
            let maxSimilarity = context.sources.map(\.similarity).max() ?? 0
            #expect(maxSimilarity < 0.15, "Expected low similarity for unrelated query, got \(maxSimilarity)")
        } else {
            #expect(!context.hasContext)
        }
    }

    @Test("getContext respects token budget")
    func getContext_respectsTokenBudget() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        let courseId = UUID()
        // Large text that will produce multiple chunks
        let largeText = String(
            repeating: "The history of mathematics spans thousands of years across many civilizations. ",
            count: 40
        )

        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: courseId,
            text: largeText
        )

        let totalChunks = await ragService.chunkCount(forDocument: docId)

        // maxTokens=50 → maxChars ~200, far too small to fit all chunks
        let context = try await ragService.getContext(
            query: "history of mathematics",
            courseId: courseId,
            maxTokens: 50
        )

        if context.hasContext && totalChunks > 1 {
            #expect(context.chunkCount < totalChunks)
        }
        // At most 1 chunk can fit in 50 tokens (~200 chars)
        #expect(context.chunkCount <= 1)
    }

    // MARK: - deleteDocument

    @Test("deleteDocument removes from index")
    func deleteDocument_removesFromIndex() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        let courseId = UUID()
        let text = String(repeating: "Content about photosynthesis and plant biology. ", count: 10)

        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: courseId,
            text: text
        )

        let countBeforeDelete = await ragService.chunkCount(forDocument: docId)
        #expect(countBeforeDelete > 0)

        try await ragService.deleteDocument(documentId: docId)

        let countAfterDelete = await ragService.chunkCount(forDocument: docId)
        #expect(countAfterDelete == 0)
    }

    // MARK: - deleteCourse

    @Test("deleteCourse removes all documents in course")
    func deleteCourse_removesAllDocumentsInCourse() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let courseId = UUID()
        let docId1 = UUID()
        let docId2 = UUID()
        let text = String(repeating: "Thermodynamics studies heat, energy, and work in physical systems. ", count: 8)

        try await ragService.indexDocument(
            documentId: docId1,
            documentType: .note,
            courseId: courseId,
            text: text
        )
        try await ragService.indexDocument(
            documentId: docId2,
            documentType: .note,
            courseId: courseId,
            text: text
        )

        #expect(await ragService.chunkCount(forDocument: docId1) > 0)
        #expect(await ragService.chunkCount(forDocument: docId2) > 0)

        try await ragService.deleteCourse(courseId: courseId)

        #expect(await ragService.chunkCount(forDocument: docId1) == 0)
        #expect(await ragService.chunkCount(forDocument: docId2) == 0)
    }

    // MARK: - isDocumentIndexed

    @Test("isDocumentIndexed returns true after indexing")
    func isDocumentIndexed_returnsTrueAfterIndexing() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")

        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let docId = UUID()
        let text = String(repeating: "Linear algebra covers vectors, matrices, and linear transformations. ", count: 8)

        try await ragService.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: UUID(),
            text: text
        )

        let indexed = await ragService.isDocumentIndexed(documentId: docId)
        #expect(indexed == true)
    }

    @Test("isDocumentIndexed returns false for unknown document")
    func isDocumentIndexed_returnsFalseForUnknownDocument() async throws {
        let (ragService, vectorStore, tempDB) = try await makeIntegrationDeps()
        defer { Task { await cleanup(vectorStore: vectorStore, tempDB: tempDB) } }

        let indexed = await ragService.isDocumentIndexed(documentId: UUID())
        #expect(indexed == false)
    }
}
