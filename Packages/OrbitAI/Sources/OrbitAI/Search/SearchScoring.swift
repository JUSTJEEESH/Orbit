import Foundation

/// Pure scoring helpers. Kept in a non-actor file so they're cheap to call
/// in a tight loop and easy to unit-test.
public enum SearchScoring {

    /// Cosine similarity, clamped to [0, 1] (opposite or unrelated vectors
    /// score 0). Returns 0 if either vector is empty or zero-magnitude.
    ///
    /// 1.x remapped [-1, 1] onto [0, 1], so unrelated text scored ~0.5 and
    /// cleared the result cutoff: nearly every embedded memory "matched".
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
        return max(0, min(1, raw))
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

    /// Sentence embeddings place even unrelated text at a modest positive
    /// cosine, so similarity below this floor carries no meaning and is
    /// rescaled to zero.
    static let semanticFloor = 0.35
    /// A memory with no word overlap must be at least this semantically
    /// relevant (after rescaling) to be shown at all.
    static let minimumSemanticOnlyRelevance = 0.25
    /// Every literal match outranks every meaning-only match: the user
    /// typed those words, so memories containing them come first.
    private static let lexicalTierBase = 0.5

    /// Rescales cosine similarity so the meaningless band below
    /// `semanticFloor` becomes 0 and a perfect match stays 1.
    public static func semanticRelevance(cosine: Double) -> Double {
        max(0, (cosine - semanticFloor) / (1 - semanticFloor))
    }

    /// Whether a memory belongs in the results at all.
    public static func isRelevant(lexical: Double, semantic: Double) -> Bool {
        lexical > 0 || semanticRelevance(cosine: semantic) >= minimumSemanticOnlyRelevance
    }

    /// Ranks a memory. Literal matches land in [0.5, 1], ordered mostly by
    /// lexical quality with semantic similarity as a tie-breaker;
    /// meaning-only matches land below 0.5.
    public static func combined(lexical: Double, semantic: Double) -> Double {
        let meaning = semanticRelevance(cosine: semantic)
        guard lexical > 0 else { return 0.45 * meaning }
        return lexicalTierBase + 0.35 * lexical + 0.15 * meaning
    }
}
