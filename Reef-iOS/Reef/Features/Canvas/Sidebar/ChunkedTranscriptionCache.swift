import PencilKit

@MainActor
final class ChunkedTranscriptionCache {
    static let chunkSize = 50

    private struct ChunkEntry {
        let fingerprint: Int
        let displayLatex: String
        let rawLatex: String
    }

    private var entries: [Int: ChunkEntry] = [:]

    /// Compute which chunks have changed since last transcription.
    /// Returns dirty chunk indices and total chunk count.
    func computeDirtyChunks(strokes: [PKStroke]) -> (dirty: Set<Int>, totalChunks: Int) {
        let totalChunks = max(1, (strokes.count + Self.chunkSize - 1) / Self.chunkSize)
        var dirty = Set<Int>()

        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * Self.chunkSize
            let end = min(start + Self.chunkSize, strokes.count)
            let fp = fingerprint(for: strokes[start..<end])

            if let existing = entries[chunkIndex], existing.fingerprint == fp {
                continue  // unchanged
            }
            dirty.insert(chunkIndex)
        }

        return (dirty, totalChunks)
    }

    /// Store transcription result for a chunk.
    func store(chunkIndex: Int, fingerprint: Int, display: String, raw: String) {
        entries[chunkIndex] = ChunkEntry(fingerprint: fingerprint, displayLatex: display, rawLatex: raw)
    }

    /// Build concatenated LaTeX from all chunks in order.
    func concatenatedResult(totalChunks: Int) -> (display: String, raw: String) {
        var displays: [String] = []
        var raws: [String] = []
        for i in 0..<totalChunks {
            if let entry = entries[i] {
                if !entry.displayLatex.isEmpty { displays.append(entry.displayLatex) }
                if !entry.rawLatex.isEmpty { raws.append(entry.rawLatex) }
            }
        }
        return (displays.joined(separator: "\n"), raws.joined(separator: "\n"))
    }

    /// Remove entries beyond the given chunk count (handles stroke deletion reducing total chunks).
    func pruneChunksAbove(_ maxIndex: Int) {
        entries = entries.filter { $0.key <= maxIndex }
    }

    /// Compute fingerprint for a slice of strokes.
    func fingerprint(for strokes: ArraySlice<PKStroke>) -> Int {
        strokes.enumerated().reduce(0) { hash, pair in
            let (i, stroke) = pair
            let b = stroke.renderBounds
            return hash &+ (b.origin.x.hashValue &* (i &+ 1))
                        &+ (b.origin.y.hashValue &* (i &+ 2))
                        &+ (b.size.width.hashValue &* (i &+ 3))
                        &+ (b.size.height.hashValue &* (i &+ 4))
        }
    }

    /// Clear everything.
    func reset() {
        entries.removeAll()
    }
}
