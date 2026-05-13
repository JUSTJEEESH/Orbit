import Foundation
import NaturalLanguage
import OrbitDomain

/// Computes `SmartInsight`s locally from the user's memories. Every detector
/// is fast, on-device, and falls back to "no insight" rather than guessing —
/// premium feel is more important than coverage.
///
/// The engine is an actor so multiple concurrent reads serialize behind a
/// single NLTagger pass when one is in flight.
public actor InsightsEngine: InsightsGenerator {
    private let extractor: EntityExtractor
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.extractor = EntityExtractor()
        self.calendar = calendar
    }

    public func generate(from memories: [Memory], now: Date) async -> [SmartInsight] {
        guard !memories.isEmpty else { return [] }

        var results: [SmartInsight] = []
        if let insight = topEntity(in: memories, now: now)      { results.append(insight) }
        if let insight = trendingCategory(in: memories, now: now) { results.append(insight) }
        if let insight = dayOfWeek(in: memories, now: now)      { results.append(insight) }
        if let insight = weeklyVolume(in: memories, now: now)   { results.append(insight) }
        return results
    }

    // MARK: - Detectors

    /// Surface the single most-mentioned person or place across the last
    /// 30 days, with at least 3 distinct memory mentions.
    private func topEntity(in memories: [Memory], now: Date) -> SmartInsight? {
        guard let windowStart = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }
        let recent = memories.filter { $0.createdAt >= windowStart }
        guard recent.count >= 3 else { return nil }

        var entityToMemoryIDs: [String: [UUID]] = [:]
        for memory in recent {
            let text = corpus(for: memory)
            guard !text.isEmpty else { continue }
            let extracted = extractor.extract(from: text)
            let entities = Set(extracted.people + extracted.locations).filter { $0.count > 1 }
            for entity in entities {
                entityToMemoryIDs[entity, default: []].append(memory.id)
            }
        }

        // Pick the entity with the most mentions; tie-break by alphabetical
        // so the surface is stable across recomputations.
        let ranked = entityToMemoryIDs
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }

        guard let top = ranked.first else { return nil }
        let mentionCount = top.value.count
        let memoryIDs = Array(Set(top.value))
        let spark = weeklySparkline(for: memoryIDs, in: memories, now: now)

        return SmartInsight(
            kind: .topEntity,
            headline: top.key,
            body: "Mentioned \(mentionCount) times this month.",
            detail: "\(top.key) has come up across \(memoryIDs.count) captures in the last 30 days. Worth a moment to revisit?",
            memoryIDs: memoryIDs,
            sparkline: spark,
            generatedAt: now
        )
    }

    /// Compare category counts in the last 7 days against the prior 7 days.
    /// Surface the biggest absolute riser when it has at least 3 captures
    /// this week AND grew by 2× or more.
    private func trendingCategory(in memories: [Memory], now: Date) -> SmartInsight? {
        guard
            let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: now),
            let priorWeekStart = calendar.date(byAdding: .day, value: -14, to: now)
        else { return nil }

        let thisWeek = memories.filter { $0.createdAt >= thisWeekStart && $0.createdAt <= now }
        let priorWeek = memories.filter { $0.createdAt >= priorWeekStart && $0.createdAt < thisWeekStart }

        let thisCounts = countsByCategory(thisWeek)
        let priorCounts = countsByCategory(priorWeek)
        guard !thisCounts.isEmpty else { return nil }

        let ranked = thisCounts
            .compactMap { (category, current) -> (String, Int, Int)? in
                guard current >= 3 else { return nil }
                let prior = priorCounts[category] ?? 0
                guard current >= max(prior * 2, prior + 2) else { return nil }
                return (category, current, prior)
            }
            .sorted { $0.1 > $1.1 }

        guard let top = ranked.first else { return nil }
        let category = top.0
        let current = top.1
        let prior = top.2
        let categoryMemories = memories.filter { $0.ai.category?.lowercased() == category.lowercased() }
        let recentIDs = thisWeek
            .filter { $0.ai.category?.lowercased() == category.lowercased() }
            .map(\.id)
        let spark = weeklySparkline(for: categoryMemories.map(\.id), in: memories, now: now)
        let priorPhrase = prior == 0 ? "none last week" : "\(prior) last week"

        return SmartInsight(
            kind: .trendingCategory,
            headline: category.capitalized,
            body: "\(current) this week, \(priorPhrase).",
            detail: "Your captures around \(category.lowercased()) are picking up. \(current) this week vs \(prior) the week before — something on your mind?",
            memoryIDs: Array(recentIDs),
            sparkline: spark,
            generatedAt: now
        )
    }

    /// Surface a weekday that dominates capture time-of-week over the last
    /// 60 days. Requires ≥10 total captures and ≥40% share.
    private func dayOfWeek(in memories: [Memory], now: Date) -> SmartInsight? {
        guard let windowStart = calendar.date(byAdding: .day, value: -60, to: now) else { return nil }
        let recent = memories.filter { $0.createdAt >= windowStart }
        guard recent.count >= 10 else { return nil }

        var dayBuckets: [Int: [UUID]] = [:]
        for memory in recent {
            let weekday = calendar.component(.weekday, from: memory.createdAt)
            dayBuckets[weekday, default: []].append(memory.id)
        }

        guard let top = dayBuckets.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let share = Double(top.value.count) / Double(recent.count)
        guard share >= 0.4 else { return nil }

        let dayName = weekdayName(for: top.key)
        return SmartInsight(
            kind: .dayOfWeek,
            headline: dayName,
            body: "You capture most on \(dayName)s.",
            detail: "About \(Int(share * 100))% of your captures over the last 60 days landed on a \(dayName). It might be your natural reflection day.",
            memoryIDs: Array(top.value),
            sparkline: [],
            generatedAt: now
        )
    }

    /// Surface a meaningful week-over-week volume change. Requires both
    /// weeks to have ≥3 captures and the swing to be ≥50%.
    private func weeklyVolume(in memories: [Memory], now: Date) -> SmartInsight? {
        guard
            let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: now),
            let priorWeekStart = calendar.date(byAdding: .day, value: -14, to: now)
        else { return nil }

        let thisWeek = memories.filter { $0.createdAt >= thisWeekStart && $0.createdAt <= now }
        let priorWeek = memories.filter { $0.createdAt >= priorWeekStart && $0.createdAt < thisWeekStart }
        guard thisWeek.count >= 3, priorWeek.count >= 3 else { return nil }

        let ratio = Double(thisWeek.count) / Double(priorWeek.count)
        guard ratio >= 1.5 || ratio <= 0.5 else { return nil }
        let isRising = ratio > 1.0
        let spark = weeklySparkline(for: memories.map(\.id), in: memories, now: now)

        return SmartInsight(
            kind: .weeklyVolume,
            headline: isRising ? "Picking up" : "Quieter week",
            body: isRising
                ? "\(thisWeek.count) captures this week, up from \(priorWeek.count)."
                : "\(thisWeek.count) captures this week, down from \(priorWeek.count).",
            detail: isRising
                ? "Your capture pace is climbing — \(thisWeek.count) this week vs \(priorWeek.count) the week before. A busier mind, or just a busier week?"
                : "You're capturing less this week — \(thisWeek.count) vs \(priorWeek.count) last week. Sometimes the quiet is the point.",
            memoryIDs: thisWeek.map(\.id),
            sparkline: spark,
            generatedAt: now
        )
    }

    // MARK: - Helpers

    /// Concatenates every textual field of a memory into a single corpus
    /// suitable for NL extraction. Empty strings filtered out.
    private func corpus(for memory: Memory) -> String {
        var parts: [String] = []
        switch memory.content {
        case .text(let s):
            parts.append(s)
        case .voiceNote(let transcript, _):
            if let transcript { parts.append(transcript) }
        case .image(let caption):
            if let caption { parts.append(caption) }
        case .link(_, let title, let summary):
            if let title { parts.append(title) }
            if let summary { parts.append(summary) }
        case .screenshot(let ocr):
            if let ocr { parts.append(ocr) }
        case .location(let name, _, _):
            if let name { parts.append(name) }
        }
        if let summary = memory.ai.summary { parts.append(summary) }
        return parts.joined(separator: " ")
    }

    private func countsByCategory(_ memories: [Memory]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for memory in memories {
            let raw = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let raw, !raw.isEmpty else { continue }
            counts[raw, default: 0] += 1
        }
        return counts
    }

    /// 8 weekly buckets (oldest → newest) counting how many of `ids` land in
    /// each week. Used to render the small bar chart on the patterns screen.
    private func weeklySparkline(for ids: [UUID], in memories: [Memory], now: Date) -> [Int] {
        let idSet = Set(ids)
        var buckets = Array(repeating: 0, count: 8)
        for memory in memories where idSet.contains(memory.id) {
            let days = calendar.dateComponents([.day], from: memory.createdAt, to: now).day ?? 0
            let weekIndex = 7 - min(7, max(0, days / 7))
            buckets[weekIndex] += 1
        }
        return buckets
    }

    private func weekdayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.standaloneWeekdaySymbols ?? []
        let index = (weekday - 1).clamped(to: 0..<symbols.count)
        return symbols.indices.contains(index) ? symbols[index] : "—"
    }
}

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1)
    }
}
