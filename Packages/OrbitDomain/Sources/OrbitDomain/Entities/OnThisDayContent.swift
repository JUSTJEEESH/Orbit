import Foundation

/// Memories captured on this exact calendar day in previous years, grouped
/// by year. The most-loved feature in Apple Photos, translated to Orbit:
/// the daily emotional pull that makes you want to open the app.
public struct OnThisDayContent: Sendable, Hashable {
    public let today: Date
    public let memoriesByYear: [YearGroup]

    public struct YearGroup: Sendable, Hashable, Identifiable {
        public let year: Int
        public let memories: [Memory]
        public var id: Int { year }

        public init(year: Int, memories: [Memory]) {
            self.year = year
            self.memories = memories
        }
    }

    public init(today: Date, memoriesByYear: [YearGroup]) {
        self.today = today
        self.memoriesByYear = memoriesByYear
    }

    public var isEmpty: Bool { memoriesByYear.isEmpty }

    /// Total memory count across all years. Surfaces as "3 memories from
    /// past years" in the Home card subtitle.
    public var totalCount: Int {
        memoriesByYear.reduce(0) { $0 + $1.memories.count }
    }

    /// The featured "wow factor" memory — the oldest available, since the
    /// year delta is what makes the surface feel like time travel.
    public var featured: Memory? {
        memoriesByYear.last?.memories.first
    }

    /// Year delta for the featured memory relative to today's year, e.g.
    /// "5 years ago today". Returns nil when there's nothing to show or
    /// the calendar math breaks down.
    public func yearsAgoForFeatured(using calendar: Calendar = .current) -> Int? {
        guard let oldestYear = memoriesByYear.last?.year else { return nil }
        let currentYear = calendar.component(.year, from: today)
        let delta = currentYear - oldestYear
        return delta > 0 ? delta : nil
    }
}
