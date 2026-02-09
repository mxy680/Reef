//
//  TutorDetectionState.swift
//  Reef
//
//  Observable state for AI tutor detection results
//

import Foundation

struct TutorDetectionResult {
    let questionIndex: Int          // 0-based
    let questionNumber: Int         // 1-based display number
    let subquestionLabel: String?   // "a", "b", "a.i", or nil for stem
    let pauseContext: PauseContext
    let timestamp: Date
}

@MainActor
final class TutorDetectionState: ObservableObject {
    @Published private(set) var currentDetection: TutorDetectionResult?

    func update(_ result: TutorDetectionResult) {
        currentDetection = result

        let partDesc = result.subquestionLabel.map { " part \($0)" } ?? ""
        print("[TutorDetection] Q\(result.questionNumber)\(partDesc) | pause: \(String(format: "%.1f", result.pauseContext.duration))s")
    }

    func clear() {
        currentDetection = nil
    }
}
