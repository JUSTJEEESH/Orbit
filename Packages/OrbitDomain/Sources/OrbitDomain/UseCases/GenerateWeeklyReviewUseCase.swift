import Foundation

/// A calm look back at the last seven days: what's still open, who you
/// thought about, the moments worth keeping, and one older memory to
/// revisit. Built entirely on device from what's already stored.
public struct WeeklyReview: Sendable, Equatable {
    public let interval: DateInterval
    public let memoryCount: Int
    public let openPromises: [MemoryTask]
    public let openTasks: [MemoryTask]
    public let people: [MentionedEntity]
    public let bestMoments: [Memory]
    public let revisit: Memory?

    public init(
        interval: DateInterval,
        memoryCount: Int,
        openPromises: [MemoryTask],
        openTasks: [MemoryTask],
        people: [MentionedEntity],
        bestMoments: [Memory],
        revisit: Memory?
    ) {
        self.interval = interval
        self.memoryCount = memoryCount
        self.openPromises = openPromises
        self.openTasks = openTasks
        self.people = people
        self.bestMoments = bestMoments
        self.revisit = revisit
    }

    public var isEmpty: Bool {
        memoryCount == 0 && openPromises.isEmpty && openTasks.isEmpty && revisit == nil
    }
}

/// When the review is offered.
public enum WeeklyReviewSchedule {
    /// Gregorian weekday number: 1 is Sunday.
    public static let weekday = 1
}

public enum WeeklyReviewPolicy {
    public static let days = 7
    public static let openItemLimit = 5
    public static let peopleLimit = 3
    public static let momentLimit = 3
    /// Text length that earns a moment its full "substance" score.
    static let substantialCharacters = 280
}

public struct GenerateWeeklyReviewUseCase: Sendable {
    private let memories: any MemoryRepository
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(memories: any MemoryRepository, tasks: any TaskRepository, clock: any OrbitClock) {
        self.memories = memories
        self.tasks = tasks
        self.clock = clock
    }

    public func callAsFunction(calendar: Calendar = .current) async throws -> WeeklyReview {
        let now = clock.now()
        let start = calendar.date(byAdding: .day, value: -WeeklyReviewPolicy.days, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(-Double(WeeklyReviewPolicy.days) * 86_400)
        let interval = DateInterval(start: start, end: now)

        let all = try await memories.list(filter: MemoryFilter(sort: .newestFirst))
        let week = all.filter { interval.contains($0.createdAt) }

        let open = try await tasks.openTasks()
        let byDue: (MemoryTask, MemoryTask) -> Bool = { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let promises = open.filter { $0.promisedTo != nil }.sorted(by: byDue)
        let others = open.filter { $0.promisedTo == nil }.sorted(by: byDue)

        var generator = SystemRandomNumberGenerator()
        let revisit = ResurfacingPicker()
            .pick(from: all, for: [calendar.startOfDay(for: now)], now: now, calendar: calendar, using: &generator)
            .first?.memory

        return WeeklyReview(
            interval: interval,
            memoryCount: week.count,
            openPromises: Array(promises.prefix(WeeklyReviewPolicy.openItemLimit)),
            openTasks: Array(others.prefix(WeeklyReviewPolicy.openItemLimit)),
            people: ListMentionedEntitiesUseCase.summarize(week, kind: .person, limit: WeeklyReviewPolicy.peopleLimit),
            bestMoments: Self.bestMoments(in: week),
            revisit: revisit
        )
    }

    /// The week's most meaningful memories: ones marked important, ones
    /// with a photo or recording, and ones with real substance. Screenshots
    /// rarely feel like "moments", so they rank last.
    static func bestMoments(in week: [Memory]) -> [Memory] {
        func score(_ memory: Memory) -> Double {
            // Importance counts double: a memory the user (or the AI)
            // marked important beats one that merely has a photo.
            var score = Double(memory.ai.priority.rawValue) * 2
            if !memory.media.isEmpty { score += 1.5 }
            score += min(1, Double(memory.analyzableText.count) / Double(WeeklyReviewPolicy.substantialCharacters))
            if case .screenshot = memory.content { score -= 2 }
            return score
        }
        return week
            .sorted { (score($0), $0.createdAt) > (score($1), $1.createdAt) }
            .prefix(WeeklyReviewPolicy.momentLimit)
            .map { $0 }
    }
}
