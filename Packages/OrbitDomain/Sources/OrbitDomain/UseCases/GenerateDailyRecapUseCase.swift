import Foundation

/// Builds a `DailyRecap` for a given day. Pulls every memory that landed
/// inside the day's calendar window, hands them to the AI service, and
/// returns the assembled recap with the AI's narrative + a server-side
/// `generatedAt` stamp.
public struct GenerateDailyRecapUseCase: Sendable {
    private let memories: any MemoryRepository
    private let ai: any AIService
    private let clock: any OrbitClock
    private let calendar: Calendar

    public init(
        memories: any MemoryRepository,
        ai: any AIService,
        clock: any OrbitClock,
        calendar: Calendar = .current
    ) {
        self.memories = memories
        self.ai = ai
        self.clock = clock
        self.calendar = calendar
    }

    /// Generates a recap for the day containing `referenceDate`. Returns
    /// `nil` when there are no memories to summarize — the UI treats
    /// "nothing to recap" as its own state, not an empty card.
    public func callAsFunction(for referenceDate: Date? = nil) async throws -> DailyRecap? {
        let now = clock.now()
        let target = referenceDate ?? now
        let startOfDay = calendar.startOfDay(for: target)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let dayMemories = try await memories.list(filter: MemoryFilter(
            dateRange: startOfDay...endOfDay,
            sort: .newestFirst
        ))

        guard !dayMemories.isEmpty else { return nil }

        let draft = try await ai.dailyRecap(memories: dayMemories, date: startOfDay)

        return DailyRecap(
            date: startOfDay,
            narrative: draft.narrative,
            highlightIDs: draft.highlightIDs.isEmpty
                ? Array(dayMemories.prefix(3).map(\.id))
                : draft.highlightIDs,
            captureCount: dayMemories.count,
            mood: draft.mood,
            generatedAt: now
        )
    }
}
