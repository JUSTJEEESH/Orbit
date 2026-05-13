import Foundation

/// Returns every memory whose `createdAt` falls on the same month-and-day
/// as today, in any previous year. Used by the Home card + the chronological
/// "On This Day" sheet.
public struct ListOnThisDayUseCase: Sendable {
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

    public func callAsFunction() async throws -> OnThisDayContent {
        let today = clock.now()
        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)
        guard let todayMonth = todayComps.month,
              let todayDay = todayComps.day,
              let todayYear = todayComps.year
        else {
            return OnThisDayContent(today: today, memoriesByYear: [])
        }

        // Pull everything and post-filter in Swift. For the bounded-scale
        // user the Tasks tab already does the same; if we ever cross 10k+
        // memories we'll add a `MemoryFilter` predicate that pushes the
        // month/day comparison down into SwiftData.
        let all = try await memories.list(filter: .all)
        let matched = all.filter { memory in
            let comps = calendar.dateComponents([.year, .month, .day], from: memory.createdAt)
            return comps.month == todayMonth
                && comps.day == todayDay
                && comps.year != todayYear
        }

        let grouped = Dictionary(grouping: matched) { memory -> Int in
            calendar.component(.year, from: memory.createdAt)
        }
        let yearGroups = grouped
            .map { (year, items) in
                OnThisDayContent.YearGroup(
                    year: year,
                    memories: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
            // Newest year first — the user's most recent past self leads.
            .sorted { $0.year > $1.year }

        return OnThisDayContent(today: today, memoriesByYear: yearGroups)
    }
}
