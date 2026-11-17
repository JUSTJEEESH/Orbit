import Foundation

/// A calendar event, reduced to what person reminders need.
public struct CalendarEventSummary: Sendable, Hashable {
    public let id: String
    public let title: String
    public let start: Date
    public let attendeeNames: [String]
    /// All-day events ("Alex's birthday") have a midnight start that
    /// mustn't be used as an alert time.
    public let isAllDay: Bool

    public init(id: String, title: String, start: Date, attendeeNames: [String], isAllDay: Bool = false) {
        self.id = id
        self.title = title
        self.start = start
        self.attendeeNames = attendeeNames
        self.isAllDay = isAllDay
    }

    /// Unique per occurrence: every occurrence of a repeating event shares
    /// the calendar's event identifier.
    public var occurrenceID: String {
        "\(id)@\(Int(start.timeIntervalSince1970))"
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
    /// All-day events ring at this hour on the day, not at midnight.
    public static let allDayAlertHour = 9

    public static func plan(
        tasks: [MemoryTask],
        events: [CalendarEventSummary],
        now: Date,
        calendar: Calendar = .current
    ) -> [PersonReminderPlan] {
        let upcoming = events
            .map { event in (event, alertDate(for: event, calendar: calendar)) }
            .filter { $0.1 > now }
            .sorted { $0.1 < $1.1 }
        return tasks.compactMap { task in
            guard !task.isCompleted, let person = task.cue?.personName,
                  let match = upcoming.first(where: { includes(person, in: $0.0) })
            else { return nil }
            let (event, fireDate) = match
            return PersonReminderPlan(
                taskID: task.id,
                taskTitle: task.title,
                person: person,
                eventTitle: event.title,
                fireDate: fireDate,
                linkedMemoryID: task.linkedMemoryID
            )
        }
    }

    /// When an event's alert rings: its start, or the morning of an
    /// all-day event.
    public static func alertDate(for event: CalendarEventSummary, calendar: Calendar = .current) -> Date {
        guard event.isAllDay else { return event.start }
        return calendar.date(bySettingHour: allDayAlertHour, minute: 0, second: 0, of: event.start) ?? event.start
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
