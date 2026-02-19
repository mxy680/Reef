//
//  FileStorageServiceTests.swift
//  ReefTests
//
//  Local integration tests for FileStorageService — no server required.
//  Uses unique UUIDs per test to avoid collisions.
//

import Testing
import Foundation
@testable import Reef

@Suite("FileStorageService", .serialized)
struct FileStorageServiceTests {

    @Test("save and load file round-trip")
    func saveAndLoadFileRoundTrip() throws {
        let documentID = UUID()
        let content = "test content"

        // Write a temp source file
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-source-\(documentID.uuidString).pdf")
        try content.data(using: .utf8)!.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        // Copy into storage
        let storedURL = try FileStorageService.shared.copyFile(
            from: sourceURL,
            documentID: documentID,
            fileExtension: "pdf"
        )
        defer { try? FileStorageService.shared.deleteFile(documentID: documentID, fileExtension: "pdf") }

        #expect(FileStorageService.shared.fileExists(documentID: documentID, fileExtension: "pdf"))

        let storedData = try Data(contentsOf: storedURL)
        #expect(storedData == content.data(using: .utf8)!)
    }

    @Test("delete file removes from storage")
    func deleteFileRemovesFromStorage() throws {
        let documentID = UUID()

        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-source-\(documentID.uuidString).pdf")
        try "delete me".data(using: .utf8)!.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        try FileStorageService.shared.copyFile(
            from: sourceURL,
            documentID: documentID,
            fileExtension: "pdf"
        )
        try FileStorageService.shared.deleteFile(documentID: documentID, fileExtension: "pdf")

        #expect(FileStorageService.shared.fileExists(documentID: documentID, fileExtension: "pdf") == false)
    }

    @Test("getFileURL returns expected path")
    func getFileURLReturnsExpectedPath() {
        let documentID = UUID()
        let url = FileStorageService.shared.getFileURL(for: documentID, fileExtension: "pdf")
        #expect(url.absoluteString.contains(documentID.uuidString))
    }

    @Test("save and delete quiz question file")
    func saveAndDeleteQuizQuestionFile() throws {
        let quizID = UUID()
        let fileName = "question-1.pdf"
        let testData = "quiz question data".data(using: .utf8)!

        try FileStorageService.shared.saveQuizQuestionFile(
            data: testData,
            quizID: quizID,
            fileName: fileName
        )

        let fileURL = FileStorageService.shared.getQuizQuestionFileURL(quizID: quizID, fileName: fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try FileStorageService.shared.deleteQuiz(quizID: quizID)

        let quizDir = FileStorageService.shared.getQuizDirectory(quizID: quizID)
        #expect(FileManager.default.fileExists(atPath: quizDir.path) == false)
    }
}
