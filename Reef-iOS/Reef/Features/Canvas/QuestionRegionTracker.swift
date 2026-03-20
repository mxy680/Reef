import Foundation

struct QuestionRegionTracker {
    /// Returns a label like "Q1a" or nil if no match.
    static func activeLabel(
        forPage page: Int,
        yPosition: Double,
        questionRegions: [QuestionRegionData?]?
    ) -> String? {
        guard let regions = questionRegions else { return nil }

        for (questionIndex, questionData) in regions.enumerated() {
            guard let data = questionData else { continue }
            for region in data.regions {
                if region.page == page && region.yStart <= yPosition && yPosition <= region.yEnd {
                    let questionNumber = questionIndex + 1
                    let partLabel = region.label ?? "a"
                    return "Q\(questionNumber)\(partLabel)"
                }
            }
        }

        return nil
    }
}
