import Foundation

/// Computes today's gratitude state + the user's consecutive-day streak.
/// Pulls every memory with the gratitude system tag and walks backward
/// from today, counting unbroken days. Bounded scale by design — the
/// pill on Home reads this on appear and it has to be cheap.
public struct LoadGratitudeStatusUseCase: Sendable {
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

    public func callAsFunction() async throws -> GratitudeStatus {
        let now = clock.now()
        let filter = MemoryFilter(
            tagNames: [GratitudeTag.name],
            sort: .newestFirst
        )
        let entries = try await memories.list(filter: filter)
        guard !entries.isEmpty else {
            return GratitudeStatus(
                hasEntryToday: false,
                streak: 0,
                lastEntryAt: nil,
                generatedAt: now
            )
        }

        let todayStart = calendar.startOfDay(for: now)
        let datesByDay = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        let hasEntryToday = datesByDay.contains(todayStart)

        // Walk back day-by-day from today (or yesterday, if today is empty
        // — the user might log late so we don't break the streak before
        // bed). Stop at the first missing day.
        var streak = 0
        var cursor = hasEntryToday ? todayStart : (calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart)
        while datesByDay.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return GratitudeStatus(
            hasEntryToday: hasEntryToday,
            streak: streak,
            lastEntryAt: entries.first?.createdAt,
            generatedAt: now
        )
    }
}
