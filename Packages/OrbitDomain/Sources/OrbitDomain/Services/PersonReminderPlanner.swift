import Foundation

/// A calendar event, reduced to what person reminders need.
public struct CalendarEventSummary: Sendable, Hashable {
    public let id: String
    public let title: String
    public let start: Date
    public let attendeeNames: [String]

    public init(id: String, title: String, start: Date, attendeeNames: [String]) {
        self.id = id
        self.title = title
        self.start = start
        self.attendeeNames = attendeeNames
    }
}

/// One alert to schedule: "Lunch with Alex · Ask about the trip".
public struct PersonReminderPlan: Sendable, Equatable {
    public let taskID: UUID
    public let taskTitle: String
    public let person: String
    public let eventTitle: String
    public let fireDate: Date
    public let linkedMemoryID: UUID?
}

/// Pairs "next time I'm with Alex" tasks with the next calendar event that
/// includes Alex (by invitee name or event title). iPhone doesn't let apps
/// know who you're physically with, so the calendar is the honest signal.
public enum PersonReminderPlanner {
    /// How far ahead events are considered.
    public static let lookahead: TimeInterval = 7 * 24 * 60 * 60

    public static func plan(tasks: [MemoryTask], events: [CalendarEventSummary], now: Date) -> [PersonReminderPlan] {
        let upcoming = events.filter { $0.start > now }.sorted { $0.start < $1.start }
        return tasks.compactMap { task in
            guard !task.isCompleted, let person = task.cue?.personName,
                  let event = upcoming.first(where: { includes(person, in: $0) })
            else { return nil }
            return PersonReminderPlan(
                taskID: task.id,
                taskTitle: task.title,
                person: person,
                eventTitle: event.title,
                fireDate: event.start,
                linkedMemoryID: task.linkedMemoryID
            )
        }
    }

    /// Whole-word, case- and accent-insensitive: "Alex" matches "Lunch
    /// with Alex" and invitee "Alex Rivera", not "Alexandra".
    public static func includes(_ person: String, in event: CalendarEventSummary) -> Bool {
        let target = words(person)
        guard !target.isEmpty else { return false }
        return ([event.title] + event.attendeeNames).contains { containsRun(target, in: words($0)) }
    }

    private static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }
            .map { String($0).replacingOccurrences(of: "’s", with: "").replacingOccurrences(of: "'s", with: "") }
    }

    private static func containsRun(_ needle: [String], in haystack: [String]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        return (0...(haystack.count - needle.count)).contains { start in
            Array(haystack[start..<(start + needle.count)]) == needle
        }
    }
}
