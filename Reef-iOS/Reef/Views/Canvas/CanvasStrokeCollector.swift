//
//  CanvasStrokeCollector.swift
//  Reef
//
//  Helpers for matching writing positions to subquestion regions
//  and collecting pen strokes for transcription.
//

import PencilKit

enum CanvasStrokeCollector {

    struct RegionMatch {
        let questionIndex: Int
        let partLabel: String?
    }

    /// Find which question and part a writing position belongs to.
    static func matchRegion(
        pageIndex: Int,
        yPDFPoints: Double,
        questionPages: [[Int]],
        questionRegions: [QuestionRegionData?]
    ) -> RegionMatch? {
        for (qi, range) in questionPages.enumerated() {
            guard range.count == 2,
                  pageIndex >= range[0] && pageIndex <= range[1],
                  qi < questionRegions.count,
                  let regionData = questionRegions[qi] else { continue }

            let localPage = pageIndex - range[0]

            for region in regionData.regions {
                if region.page == localPage &&
                   yPDFPoints >= region.yStart &&
                   yPDFPoints <= region.yEnd {
                    return RegionMatch(questionIndex: qi, partLabel: region.label)
                }
            }

            // Page is within this question but no region matched.
            // If the question has subquestion regions, the user is annotating.
            if !regionData.regions.isEmpty {
                return RegionMatch(questionIndex: qi, partLabel: nil)
            }
        }
        return nil
    }

    /// Collect all pen strokes in matching regions for a given question and part label.
    static func collectStrokes(
        questionIndex: Int,
        partLabel: String,
        questionPages: [[Int]],
        questionRegions: [QuestionRegionData?],
        drawingManager: DrawingManager
    ) -> [[(x: Double, y: Double)]] {
        guard questionPages[questionIndex].count == 2,
              let regionData = questionRegions[questionIndex] else { return [] }

        let startPage = questionPages[questionIndex][0]
        let endPage = questionPages[questionIndex][1]
        let matchingRegions = regionData.regions.filter { $0.label == partLabel }
        guard !matchingRegions.isEmpty else { return [] }

        var allStrokes: [[(x: Double, y: Double)]] = []

        for absPage in startPage...endPage {
            let localPage = absPage - startPage
            let pageRegions = matchingRegions.filter { $0.page == localPage }
            guard !pageRegions.isEmpty else { continue }

            let drawing = drawingManager.drawing(for: absPage)
            for stroke in drawing.strokes {
                guard stroke.ink.inkType == .pen else { continue }

                let midY = stroke.renderBounds.midY / 2.0 // Canvas coords to PDF points
                let inRegion = pageRegions.contains { $0.yStart <= midY && midY <= $0.yEnd }
                guard inRegion else { continue }

                var points: [(x: Double, y: Double)] = []
                for i in stride(from: 0, to: stroke.path.count, by: 1) {
                    let loc = stroke.path[i].location
                    points.append((x: Double(loc.x), y: Double(loc.y)))
                }
                if !points.isEmpty {
                    allStrokes.append(points)
                }
            }
        }

        return normalizeStrokes(allStrokes)
    }

    /// Translate all strokes so the bounding box starts at (0,0).
    static func normalizeStrokes(_ strokes: [[(x: Double, y: Double)]]) -> [[(x: Double, y: Double)]] {
        guard !strokes.isEmpty else { return strokes }
        var minX = Double.infinity, minY = Double.infinity
        for stroke in strokes {
            for pt in stroke {
                minX = min(minX, pt.x)
                minY = min(minY, pt.y)
            }
        }
        return strokes.map { $0.map { (x: $0.x - minX, y: $0.y - minY) } }
    }
}
