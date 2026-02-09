//
//  RegionResolver.swift
//  Reef
//
//  Maps a PDF position to a subquestion region
//

import Foundation

struct ResolvedRegion {
    /// Subquestion label (e.g. "a", "b", "a.i"), or nil for the question stem
    let label: String?
}

enum RegionResolver {

    /// Resolves which subquestion a given position falls within.
    /// - Parameters:
    ///   - pdfY: Y position in PDF points
    ///   - page: 0-indexed page within this question's PDF
    ///   - regionData: Region data from the server
    /// - Returns: The resolved region, or nil if no region data is available
    static func resolve(pdfY: Float, page: Int, regionData: ProblemRegionData?) -> ResolvedRegion? {
        guard let regionData = regionData else { return nil }

        let pageRegions = regionData.regions.filter { $0.page == page }
        guard !pageRegions.isEmpty else { return nil }

        // Find exact match: yStart <= pdfY < yEnd
        if let match = pageRegions.first(where: { pdfY >= $0.yStart && pdfY < $0.yEnd }) {
            return ResolvedRegion(label: match.label)
        }

        // Fallback: nearest region (safety net for gaps between regions)
        let nearest = pageRegions.min(by: { region1, region2 in
            let dist1 = min(abs(pdfY - region1.yStart), abs(pdfY - region1.yEnd))
            let dist2 = min(abs(pdfY - region2.yStart), abs(pdfY - region2.yEnd))
            return dist1 < dist2
        })

        if let nearest = nearest {
            return ResolvedRegion(label: nearest.label)
        }

        return nil
    }
}
