import Foundation

struct QuestionRegionTracker {
    /// Returns a label like "Q1a" or nil if no match.
    /// Uses questionPages for reliable question-level detection (which page = which question),
    /// then tries region data for subquestion precision.
    static func activeLabel(
        forPage page: Int,
        yPosition: Double,
        questionRegions: [QuestionRegionData?]?,
        questionPages: [[Int]]?
    ) -> String? {
        guard let qPages = questionPages, !qPages.isEmpty else { return nil }

        // Step 1: Find which question this page belongs to using questionPages
        var questionIndex: Int?
        for (qi, pageRange) in qPages.enumerated() {
            guard pageRange.count >= 2 else { continue }
            let startPage = pageRange[0]
            let endPage = pageRange[1]
            if page >= startPage && page <= endPage {
                questionIndex = qi
                break
            }
        }

        guard let qi = questionIndex else { return nil }
        let questionNumber = qi + 1

        // Step 2: Try to find the subquestion using region data
        if let regions = questionRegions, qi < regions.count, let data = regions[qi] {
            let pageOffset = qPages[qi][0]
            let localPage = page - pageOffset

            // Find all regions on this local page, pick the one containing yPosition
            // Scale Y proportionally if needed: regions are from compiled question PDF,
            // but the merged page should have matching coordinates
            for region in data.regions {
                if region.page == localPage && region.yStart <= yPosition && yPosition <= region.yEnd {
                    let partLabel = region.label ?? "a"
                    return "Q\(questionNumber)\(partLabel)"
                }
            }

            // No exact subquestion match — find the closest region on this page
            let pageRegions = data.regions.filter { $0.page == localPage }
            if !pageRegions.isEmpty {
                // Find the region whose range is closest to yPosition
                var bestRegion: PartRegion?
                var bestDist = Double.infinity
                for region in pageRegions {
                    let dist: Double
                    if yPosition < region.yStart {
                        dist = region.yStart - yPosition
                    } else if yPosition > region.yEnd {
                        dist = yPosition - region.yEnd
                    } else {
                        dist = 0
                    }
                    if dist < bestDist {
                        bestDist = dist
                        bestRegion = region
                    }
                }
                if let best = bestRegion {
                    let partLabel = best.label ?? "a"
                    return "Q\(questionNumber)\(partLabel)"
                }
            }
        }

        // Fallback: just the question number
        return "Q\(questionNumber)a"
    }
}
