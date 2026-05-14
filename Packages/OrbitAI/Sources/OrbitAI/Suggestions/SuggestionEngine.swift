import Foundation
import OrbitDomain

/// Computes the Home tab's "Worth revisiting" surface. The shape mirrors
/// `InsightsEngine`: an actor so concurrent reads serialize, plus pure
/// detector helpers that take a memory list and a clock-supplied `now`.
///
/// Ranking model (composite score against the anchor):
///     score = 0.55 · cosineSim(anchor.embedding, candidate.embedding)
///           + 0.30 · entityOverlap(anchor, candidate)        // Jaccard
///           + 0.15 · recencyDecay(candidate.createdAt)       // newer = higher
///           − penalties (same day, < 7 days apart, sealed, anchor itself)
///
/// All knobs are tuned for the <5k-memory regime documented in the search
/// service. At larger corpora we'd want HNSW + candidate pruning before the
/// pairwise pass.
public actor SuggestionEngine: SuggestionGenerator {
    private let calendar: Calendar
    /// Anchor must be at least this old. Picking from the last 7 days would
    /// surface things the user remembers vividly, defeating the "revisit"
    /// framing.
    private let anchorMinAgeDays: Int = 7
    /// Anchor must be no older than this. Older memories are still findable
    /// via Timeline / Search; the Home surface should feel current-ish.
    private let anchorMaxAgeDays: Int = 60
    /// On Home, we don't surface related memories captured within this
    /// window of the anchor — too close together usually means same
    /// thought, same evening. On Memory Detail (explicit anchor), the
    /// caller passes 0 because same-day connections are meaningful when
    /// the user is staring at a specific memory.
    private let homeMinSeparationDays: Int = 7
    /// Max related memories to return. Three keeps the surface calm.
    private let maxRelated: Int = 3
    /// Floor below which a candidate doesn't qualify. Empirical — anything
    /// below ~0.35 reads as random on real corpora.
    private let scoreFloor: Double = 0.35

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Public — Home surface (auto-picked anchor)

    public func suggestions(
        from memories: [Memory],
        dismissedIDs: Set<UUID>,
        now: Date
    ) async -> MemorySuggestionFeed? {
        // Dismissals filter the pool before anchor selection — a
        // memory the user hid shouldn't be re-elected as today's
        // memory-of-the-day, and it can't surface as a related result
        // either.
        let pool = memories.filter { !$0.isSealed(at: now) && !dismissedIDs.contains($0.id) }
        guard pool.count >= 5 else { return nil }

        guard let anchor = pickAnchor(from: pool, now: now) else { return nil }
        let related = rank(candidates: pool, anchor: anchor, now: now, minSeparationDays: homeMinSeparationDays)
        guard !related.isEmpty else { return nil }

        return MemorySuggestionFeed(anchor: anchor, related: related, generatedAt: now)
    }

    // MARK: - Public — Memory Detail surface (explicit anchor)

    /// Caller passes the memory the user is viewing; we return the
    /// top-ranked related memories from the wider corpus. No day-window
    /// gate on the anchor (it's whatever the user tapped); no day-gap
    /// requirement on candidates (same-day captures can legitimately
    /// connect to the one being viewed).
    ///
    /// The anchor itself is never filtered out by `dismissedIDs` (the
    /// user is actively viewing it); only candidates are.
    public func relatedMemories(
        anchor: Memory,
        from memories: [Memory],
        dismissedIDs: Set<UUID>,
        now: Date
    ) async -> [MemorySuggestionFeed.Related] {
        let pool = memories.filter { !$0.isSealed(at: now) && !dismissedIDs.contains($0.id) }
        return rank(candidates: pool, anchor: anchor, now: now, minSeparationDays: 0)
    }

    // MARK: - Anchor selection (option c — deterministic memory-of-the-day)

    /// Picks one memory from the eligible window using a date-seeded hash.
    /// The result is stable for the whole calendar day and rotates at
    /// midnight, giving Home the same calm "today's reflection" quality
    /// Apple Journal lands.
    private func pickAnchor(from memories: [Memory], now: Date) -> Memory? {
        guard
            let oldestEligible = calendar.date(byAdding: .day, value: -anchorMaxAgeDays, to: now),
            let newestEligible = calendar.date(byAdding: .day, value: -anchorMinAgeDays, to: now)
        else { return nil }

        let eligible = memories
            .filter { $0.createdAt >= oldestEligible && $0.createdAt <= newestEligible }
            // Avoid letters and surfaced-only-on-date memories as anchors —
            // they have their own dedicated surfaces (envelopes, sealed
            // delivery). Suggesting them here would feel duplicative.
            .filter { !$0.isLetter }
            // Stable order so the seeded pick is deterministic across
            // recomputations on the same day.
            .sorted { $0.id.uuidString < $1.id.uuidString }

        guard !eligible.isEmpty else { return nil }

        let daySeed = daySeed(for: now)
        let index = daySeed % UInt64(eligible.count)
        return eligible[Int(index)]
    }

    /// Mixes the calendar day into a 64-bit seed. Same day → same index.
    private func daySeed(for now: Date) -> UInt64 {
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let year = UInt64(comps.year ?? 2026)
        let month = UInt64(comps.month ?? 1)
        let day = UInt64(comps.day ?? 1)
        // Simple mix — good enough for one bucket pick per day.
        var seed = year &* 1_000_000 &+ month &* 1_000 &+ day
        seed ^= seed >> 33
        seed &*= 0xff51afd7ed558ccd
        seed ^= seed >> 33
        return seed
    }

    // MARK: - Ranking

    private func rank(
        candidates: [Memory],
        anchor: Memory,
        now: Date,
        minSeparationDays: Int
    ) -> [MemorySuggestionFeed.Related] {
        let anchorEntities = entitySet(for: anchor)

        let scored: [MemorySuggestionFeed.Related] = candidates.compactMap { candidate in
            guard candidate.id != anchor.id else { return nil }
            let daysApart = abs(daysBetween(candidate.createdAt, anchor.createdAt))
            guard daysApart >= minSeparationDays else { return nil }

            let semantic = cosineSimilarity(anchor.embedding, candidate.embedding)
            let entity = jaccard(anchorEntities, entitySet(for: candidate))
            let recency = recencyDecay(candidate.createdAt, now: now)
            let score = 0.55 * semantic + 0.30 * entity + 0.15 * recency

            guard score >= scoreFloor else { return nil }
            return MemorySuggestionFeed.Related(memory: candidate, score: score)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(maxRelated)
            .map { $0 }
    }

    // MARK: - Score helpers

    /// Cosine similarity mapped from [-1, 1] to [0, 1]. Mirrors the
    /// LocalSearchService formula so the two surfaces agree on what
    /// "similar" means.
    private func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
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
        return max(0, min(1, (raw + 1) / 2))
    }

    /// Jaccard similarity over the merged people-and-locations sets.
    private func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    /// 1.0 today, ~0.7 at 30 days, ~0.5 at 90 days, ~0.2 at one year.
    /// Smooths to 0 at 2 years.
    private func recencyDecay(_ date: Date, now: Date) -> Double {
        let days = max(0, daysBetween(date, now))
        if days >= 730 { return 0 }
        // Exponential with half-life ~120 days.
        return pow(0.5, Double(days) / 120.0)
    }

    private func entitySet(for memory: Memory) -> Set<String> {
        // Lowercase + trim so casing/whitespace doesn't fragment the set.
        let people = memory.ai.extractedPeople.map { normalize($0) }
        let places = memory.ai.extractedLocations.map { normalize($0) }
        return Set((people + places).filter { !$0.isEmpty })
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        let start = calendar.startOfDay(for: min(a, b))
        let end = calendar.startOfDay(for: max(a, b))
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
