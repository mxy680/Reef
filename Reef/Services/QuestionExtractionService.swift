//
//  QuestionExtractionService.swift
//  Reef
//
//  Service for extracting questions from assignment PDFs via server API.
//

import Foundation

// MARK: - API Models

struct SubmitExtractionRequest: Codable {
    let pdf_base64: String
    let note_id: String
}

struct SubmitExtractionResponse: Codable {
    let job_id: String
    let status: String
}

struct JobStatusResponse: Codable {
    let job_id: String
    let status: String
    let error_message: String?
}

struct QuestionData: Codable {
    let order_index: Int
    let question_number: String
    let pdf_base64: String
    let has_images: Bool?
    let has_tables: Bool?
}

struct ExtractQuestionsResponse: Codable {
    let questions: [QuestionData]
    let note_id: String
    let total_count: Int
}

// MARK: - Error Types

enum QuestionExtractionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData
    case jobFailed(message: String)
    case fileReadError
    case fileWriteError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        case .jobFailed(let message):
            return "Extraction failed: \(message)"
        case .fileReadError:
            return "Failed to read PDF file"
        case .fileWriteError:
            return "Failed to save extracted question"
        }
    }
}

// MARK: - Job Status

enum ExtractionJobStatus: String {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - QuestionExtractionService

/// Service for extracting questions from assignment PDFs
actor QuestionExtractionService {
    static let shared = QuestionExtractionService()

    private let baseURL = "https://mxy680--reef-server-reefserver-web-app.modal.run"
    private let session: URLSession
    private let pollInterval: TimeInterval = 3.0  // Poll every 3 seconds

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180  // 3 minutes for long operations
        config.timeoutIntervalForResource = 300  // 5 minutes total
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Submit a PDF for question extraction
    /// - Parameters:
    ///   - fileURL: URL to the PDF file
    ///   - noteID: UUID of the note for tracking
    /// - Returns: Job ID for polling status
    func submitExtraction(fileURL: URL, noteID: UUID) async throws -> String {
        // Read PDF and encode to base64
        guard let pdfData = try? Data(contentsOf: fileURL) else {
            throw QuestionExtractionError.fileReadError
        }
        let base64PDF = pdfData.base64EncodedString()

        // Build request
        let request = SubmitExtractionRequest(
            pdf_base64: base64PDF,
            note_id: noteID.uuidString
        )

        guard let url = URL(string: baseURL + "/ai/extract-questions/submit") else {
            throw QuestionExtractionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw QuestionExtractionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionExtractionError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractErrorMessage(from: data)
            throw QuestionExtractionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let submitResponse = try JSONDecoder().decode(SubmitExtractionResponse.self, from: data)
        return submitResponse.job_id
    }

    /// Poll for job status
    /// - Parameter jobID: The job ID returned from submitExtraction
    /// - Returns: Current job status
    func getJobStatus(jobID: String) async throws -> ExtractionJobStatus {
        guard let url = URL(string: baseURL + "/ai/extract-questions/\(jobID)/status") else {
            throw QuestionExtractionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw QuestionExtractionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionExtractionError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractErrorMessage(from: data)
            throw QuestionExtractionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let statusResponse = try JSONDecoder().decode(JobStatusResponse.self, from: data)

        if let status = ExtractionJobStatus(rawValue: statusResponse.status) {
            if status == .failed, let errorMessage = statusResponse.error_message {
                throw QuestionExtractionError.jobFailed(message: errorMessage)
            }
            return status
        }

        return .pending
    }

    /// Get extraction results after job completes
    /// - Parameter jobID: The job ID
    /// - Returns: List of extracted questions with PDF data
    func getResults(jobID: String) async throws -> ExtractQuestionsResponse {
        guard let url = URL(string: baseURL + "/ai/extract-questions/\(jobID)/results") else {
            throw QuestionExtractionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw QuestionExtractionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionExtractionError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractErrorMessage(from: data)
            throw QuestionExtractionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(ExtractQuestionsResponse.self, from: data)
    }

    /// Extract questions from a PDF file (full flow with polling)
    /// - Parameters:
    ///   - fileURL: URL to the PDF file
    ///   - noteID: UUID of the note
    ///   - onStatusUpdate: Callback for status updates
    /// - Returns: Array of extracted questions saved locally
    func extractQuestions(
        fileURL: URL,
        noteID: UUID,
        onStatusUpdate: ((ExtractionJobStatus) -> Void)? = nil
    ) async throws -> [ExtractedQuestion] {
        // Submit job
        let jobID = try await submitExtraction(fileURL: fileURL, noteID: noteID)
        onStatusUpdate?(.processing)

        // Poll for completion
        var status: ExtractionJobStatus = .pending
        while status == .pending || status == .processing {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            status = try await getJobStatus(jobID: jobID)
            onStatusUpdate?(status)
        }

        if status == .failed {
            throw QuestionExtractionError.jobFailed(message: "Extraction failed")
        }

        // Get results
        let results = try await getResults(jobID: jobID)

        // Save question PDFs locally
        var extractedQuestions: [ExtractedQuestion] = []
        for questionData in results.questions {
            let savedQuestion = try saveQuestionPDF(
                questionData: questionData,
                noteID: noteID
            )
            extractedQuestions.append(savedQuestion)
        }

        return extractedQuestions
    }

    // MARK: - Private Helpers

    private func extractErrorMessage(from data: Data) -> String {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
           let detail = errorDict["detail"] {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    /// Save a question PDF to local storage
    /// Uses the note ID as the question set ID for storage
    private func saveQuestionPDF(questionData: QuestionData, noteID: UUID) throws -> ExtractedQuestion {
        guard let pdfData = Data(base64Encoded: questionData.pdf_base64) else {
            throw QuestionExtractionError.fileWriteError
        }

        let fileName = "question_\(questionData.order_index).pdf"

        do {
            try FileStorageService.shared.saveQuestionFile(
                data: pdfData,
                questionSetID: noteID,  // Use note ID as question set ID
                fileName: fileName
            )
        } catch {
            throw QuestionExtractionError.fileWriteError
        }

        return ExtractedQuestion(
            questionNumber: questionData.order_index + 1,  // 1-based for display
            pdfFileName: fileName
        )
    }
}
