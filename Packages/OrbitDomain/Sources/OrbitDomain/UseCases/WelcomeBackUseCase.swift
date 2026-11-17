import Foundation

/// What Home says after time away: how long it's been and what's still
/// open, without guilt. Orbit never counts streaks, so there's nothing to
/// have broken. (Day One users petition to hide streaks; ADHD users leave
/// apps over them.)
public struct WelcomeBack: Sendable, Equatable {
    public let daysAway: Int
    /// The few open items worth seeing first: promises, then soonest due.
    public let highlights: [MemoryTask]
    /// Every open item, for "and 4 more".
    public let openCount: Int

    public init(daysAway: Int, highlights: [MemoryTask], openCount: Int) {
        self.daysAway = daysAway
        self.highlights = highlights
        self.openCount = openCount
    }
}

public enum WelcomeBackPolicy {
    /// Shorter breaks are ordinary life, not "time away".
    public static let minimumDaysAway = 4
    /// Enough to orient, few enough to stay calm.
    public static let highlightCount = 3
}

public struct LoadWelcomeBackUseCase: Sendable {
    private let tasks: any TaskRepository

    public init(tasks: any TaskRepository) {
        self.tasks = tasks
    }

    /// - Returns: nil on a first launch or after a short break.
    public func callAsFunction(lastVisit: Date?, now: Date, calendar: Calendar = .current) async throws -> WelcomeBack? {
        guard let lastVisit else { return nil }
        let days = TimeSince.days(from: lastVisit, to: now, calendar: calendar)
        guard days >= WelcomeBackPolicy.minimumDaysAway else { return nil }
        let open = try await tasks.openTasks()
        let ordered = open.sorted { lhs, rhs in
            let lhsPromise = lhs.promisedTo != nil
            let rhsPromise = rhs.promisedTo != nil
            if lhsPromise != rhsPromise { return lhsPromise }
            return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
        }
        return WelcomeBack(
            daysAway: days,
            highlights: Array(ordered.prefix(WelcomeBackPolicy.highlightCount)),
            openCount: open.count
        )
    }
}
