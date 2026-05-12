import Foundation

public struct HabitStats: Sendable, Hashable, Identifiable {
    public let habit: String
    public let totalMentions: Int
    public let lastMentionedAt: Date
    /// 12 weekly buckets (oldest → newest). Powers the per-habit sparkline.
    public let weeklyCounts: [Int]
    /// Source memories so the UI can deep-link to them.
    public let memoryIDs: [UUID]
    public var id: String { habit }

    public init(
        habit: String,
        totalMentions: Int,
        lastMentionedAt: Date,
        weeklyCounts: [Int],
        memoryIDs: [UUID]
    ) {
        self.habit = habit
        self.totalMentions = totalMentions
        self.lastMentionedAt = lastMentionedAt
        self.weeklyCounts = weeklyCounts
        self.memoryIDs = memoryIDs
    }
}

/// Aggregates every memory's `signals.habitMentions` into per-habit stats:
/// total mentions, last-mentioned date, and a 12-week cadence array. Used
/// by the Habits view to render an emergent habit tracker — the user never
/// has to define habits up front; they just appear once enough mentions
/// pile up.
public struct ListHabitsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let clock: any OrbitClock
    private let calendar: Calendar
    private let weeksBack: Int

    public init(
        memories: any MemoryRepository,
        clock: any OrbitClock,
        calendar: Calendar = .current,
        weeksBack: Int = 12
    ) {
        self.memories = memories
        self.clock = clock
        self.calendar = calendar
        self.weeksBack = weeksBack
    }

    public func callAsFunction() async throws -> [HabitStats] {
        let now = clock.now()
        let all = try await memories.list(filter: .all)

        struct Bucket {
            var mentions: [HabitMention] = []
            var memoryIDs: [UUID] = []
        }
        var bucket: [String: Bucket] = [:]

        for memory in all {
            for mention in memory.ai.signals.habitMentions {
                bucket[mention.habit, default: Bucket()].mentions.append(mention)
                bucket[mention.habit]?.memoryIDs.append(memory.id)
            }
        }

        return bucket.map { habit, data in
            HabitStats(
                habit: habit,
                totalMentions: data.mentions.count,
                lastMentionedAt: data.mentions.map(\.occurredAt).max() ?? now,
                weeklyCounts: weeklyCounts(for: data.mentions, now: now),
                memoryIDs: Array(Set(data.memoryIDs))
            )
        }
        .sorted { lhs, rhs in
            // Most-mentioned first; ties broken by most-recent.
            if lhs.totalMentions != rhs.totalMentions { return lhs.totalMentions > rhs.totalMentions }
            return lhs.lastMentionedAt > rhs.lastMentionedAt
        }
    }

    private func weeklyCounts(for mentions: [HabitMention], now: Date) -> [Int] {
        var buckets = Array(repeating: 0, count: weeksBack)
        for mention in mentions {
            let days = calendar.dateComponents([.day], from: mention.occurredAt, to: now).day ?? 0
            let weekIndex = weeksBack - 1 - min(weeksBack - 1, max(0, days / 7))
            if weekIndex >= 0 {
                buckets[weekIndex] += 1
            }
        }
        return buckets
    }
}
