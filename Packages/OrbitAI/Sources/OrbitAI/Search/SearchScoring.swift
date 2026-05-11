import Foundation

/// Pure scoring helpers. Kept in a non-actor file so they're cheap to call
/// in a tight loop and easy to unit-test.
public enum SearchScoring {

    /// Cosine similarity, clamped to [0, 1]. Returns 0 if either vector is
    /// empty or zero-magnitude.
    public static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return 0 }
        var dot: Float = 0
        var lhsMag: Float = 0
        var rhsMag: Float = 0
        for i in 0..<lhs.count {
            dot += lhs[i] * rhs[i]
            lhsMag += lhs[i] * lhs[i]
            rhsMag += rhs[i] * rhs[i]
        }
        let magnitude = (lhsMag * rhsMag).squareRoot()
        guard magnitude > 0 else { return 0 }
        let raw = Double(dot / magnitude)
        return max(0, min(1, (raw + 1) / 2)) // map [-1, 1] -> [0, 1]
    }

    /// Simple lexical relevance: counts query-token hits and rewards earlier
    /// matches and longer overlap. Not BM25 — we add a real BM25 once we
    /// have enough memories that ranking quality outpaces simple recall.
    public static func lexicalScore(query: String, in haystack: String) -> Double {
        let q = query.lowercased()
        let h = haystack.lowercased()
        guard !q.isEmpty, !h.isEmpty else { return 0 }

        let separators = CharacterSet.alphanumerics.inverted
        let tokens = q
            .components(separatedBy: separators)
            .filter { $0.count > 1 }
        guard !tokens.isEmpty else {
            // Single-character or punctuation-only query: substring fallback.
            return h.contains(q) ? 0.4 : 0
        }

        var hits = 0
        var earliest = Int.max
        for token in tokens {
            if let range = h.range(of: token) {
                hits += 1
                let offset = h.distance(from: h.startIndex, to: range.lowerBound)
                if offset < earliest { earliest = offset }
            }
        }
        guard hits > 0 else { return 0 }
        let recall = Double(hits) / Double(tokens.count)
        // Earlier matches feel more relevant; decay slowly over the first
        // few hundred characters.
        let earlinessBonus = 0.2 * max(0, 1 - Double(earliest) / 400.0)
        return min(1, 0.8 * recall + earlinessBonus)
    }

    /// Linearly blends lexical and semantic scores. Phase 4 ranking — we'll
    /// upgrade to reciprocal rank fusion once we have query benchmarks.
    public static func combined(lexical: Double, semantic: Double) -> Double {
        // When semantic is unavailable (empty embedding -> 0), the formula
        // still produces useful ordering from the lexical signal alone.
        0.45 * lexical + 0.55 * semantic
    }
}
