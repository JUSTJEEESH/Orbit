import Foundation

/// Builds a `YearInReview` for a given calendar year. Pulls every memory
/// captured in that year, computes totals + top entities + monthly cadence,
/// and hand-picks five highlight memories that read as the year's arc:
/// the first capture, the last, and the top three by priority.
public struct GenerateYearInReviewUseCase: Sendable {
    private let memories: any MemoryRepository
    private let clock: any OrbitClock
    private let calendar: Calendar

    public init(
        memories: any MemoryRepository,
        clock: any OrbitClock,
        calendar: Calendar = .current
    ) {
        self.memories = memories
        self.clock = clock
        self.calendar = calendar
    }

    /// Builds the review for `year`. When called without a year, defaults to
    /// the most recently-completed calendar year (or the current year if
    /// we're past December 1 — so users get a preview while the year is
    /// still finishing).
    public func callAsFunction(for year: Int? = nil) async throws -> YearInReview {
        let now = clock.now()
        let resolvedYear = year ?? defaultYear(for: now)

        guard
            let startOfYear = calendar.date(from: DateComponents(year: resolvedYear, month: 1, day: 1)),
            let endOfYear = calendar.date(from: DateComponents(year: resolvedYear + 1, month: 1, day: 1))
        else {
            return YearInReview(
                year: resolvedYear,
                totalCaptures: 0,
                kindBreakdown: [],
                topCategory: nil,
                topPerson: nil,
                topPlace: nil,
                mostActiveMonth: nil,
                monthlyCounts: emptyMonthlyCounts,
                highlights: [],
                generatedAt: now
            )
        }

        // Include sealed so a user's time-capsules still count toward their
        // yearly stats — the review is reflective, not surfacing.
        var filter = MemoryFilter(
            dateRange: startOfYear...endOfYear,
            sort: .oldestFirst,
            includeSealed: true
        )
        filter.dateRange = startOfYear...endOfYear
        let yearMemories = try await memories.list(filter: filter)

        guard !yearMemories.isEmpty else {
            return YearInReview(
                year: resolvedYear,
                totalCaptures: 0,
                kindBreakdown: [],
                topCategory: nil,
                topPerson: nil,
                topPlace: nil,
                mostActiveMonth: nil,
                monthlyCounts: emptyMonthlyCounts,
                highlights: [],
                generatedAt: now
            )
        }

        let kindBreakdown = buildKindBreakdown(yearMemories)
        let monthlyCounts = buildMonthlyCounts(yearMemories)
        let mostActiveMonth = monthlyCounts.max(by: { $0.count < $1.count })?.month

        return YearInReview(
            year: resolvedYear,
            totalCaptures: yearMemories.count,
            kindBreakdown: kindBreakdown,
            topCategory: topNamedCount(from: yearMemories) { $0.ai.category.map { [$0] } ?? [] },
            topPerson: topNamedCount(from: yearMemories) { $0.ai.extractedPeople },
            topPlace: topNamedCount(from: yearMemories) { $0.ai.extractedLocations },
            mostActiveMonth: mostActiveMonth,
            monthlyCounts: monthlyCounts,
            highlights: pickHighlights(from: yearMemories),
            generatedAt: now
        )
    }

    // MARK: - Helpers

    private func defaultYear(for date: Date) -> Int {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let month = comps.month, let year = comps.year else { return 1970 }
        // Before December: review the year that just ended. December onward:
        // start previewing the current year early.
        return month >= 12 ? year : year - 1
    }

    private func buildKindBreakdown(_ memories: [Memory]) -> [YearInReview.KindStat] {
        var counts: [MemoryContentKind: Int] = [:]
        for memory in memories {
            counts[memory.content.kind, default: 0] += 1
        }
        return counts
            .map { YearInReview.KindStat(kind: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func buildMonthlyCounts(_ memories: [Memory]) -> [YearInReview.MonthlyCount] {
        var counts: [Int: Int] = [:]
        for memory in memories {
            let month = calendar.component(.month, from: memory.createdAt)
            counts[month, default: 0] += 1
        }
        return (1...12).map { month in
            YearInReview.MonthlyCount(month: month, count: counts[month] ?? 0)
        }
    }

    /// Builds the most-frequent NamedCount from per-memory string arrays.
    /// Trims + lowercases for grouping; presents the trimmed-but-otherwise-
    /// original form for display so "Pamela" doesn't render as "Pamela".
    private func topNamedCount(
        from memories: [Memory],
        arrays: (Memory) -> [String]
    ) -> YearInReview.NamedCount? {
        var bucket: [String: (display: String, count: Int)] = [:]
        for memory in memories {
            for raw in arrays(memory) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let key = trimmed.lowercased()
                bucket[key, default: (trimmed, 0)].count += 1
                bucket[key]?.display = trimmed
            }
        }
        return bucket
            .map { YearInReview.NamedCount(name: $0.value.display, count: $0.value.count) }
            .max(by: { $0.count < $1.count })
    }

    /// Picks up to 5 memories that read as the year's arc. First chronological
    /// + last chronological always make the cut (bookends), then the top
    /// remaining slots fill with highest-priority captures.
    private func pickHighlights(from memories: [Memory]) -> [Memory] {
        let sorted = memories.sorted { $0.createdAt < $1.createdAt }
        var picked: [UUID: Memory] = [:]
        if let first = sorted.first { picked[first.id] = first }
        if let last = sorted.last { picked[last.id] = last }
        let byPriority = memories
            .filter { picked[$0.id] == nil }
            .sorted { ($0.ai.priority, $0.createdAt) > ($1.ai.priority, $1.createdAt) }
        for memory in byPriority {
            if picked.count >= 5 { break }
            picked[memory.id] = memory
        }
        return picked.values.sorted { $0.createdAt < $1.createdAt }
    }

    private var emptyMonthlyCounts: [YearInReview.MonthlyCount] {
        (1...12).map { YearInReview.MonthlyCount(month: $0, count: 0) }
    }
}
