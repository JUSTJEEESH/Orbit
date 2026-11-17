import Foundation

/// What Orbit knows about one person you're about to see.
public struct PersonBrief: Sendable, Hashable, Identifiable {
    public let name: String
    /// `MentionedEntity.key`, for de-duplicating spellings.
    public let key: String
    /// The last memory that reads like you were in touch ("called Alex").
    public let lastContact: Date?
    /// Promises you made them that are still open.
    public let openPromises: [MemoryTask]
    /// "Next time I'm with Alex…" tasks: things to bring up.
    public let toBringUp: [MemoryTask]
    /// Memories that sound like gift ideas for them.
    public let giftIdeas: [Memory]
    /// The most recent other memories that mention them.
    public let recentMoments: [Memory]

    public var id: String { key }

    public init(
        name: String,
        key: String,
        lastContact: Date?,
        openPromises: [MemoryTask],
        toBringUp: [MemoryTask],
        giftIdeas: [Memory],
        recentMoments: [Memory]
    ) {
        self.name = name
        self.key = key
        self.lastContact = lastContact
        self.openPromises = openPromises
        self.toBringUp = toBringUp
        self.giftIdeas = giftIdeas
        self.recentMoments = recentMoments
    }

    /// Nothing worth showing: a name in the calendar Orbit knows nothing
    /// about.
    public var isEmpty: Bool {
        openPromises.isEmpty && toBringUp.isEmpty && giftIdeas.isEmpty && recentMoments.isEmpty
    }
}

/// "Before lunch with Alex": what you last talked about, what you promised,
/// what to bring up. Built on device from memories and tasks for one
/// calendar event.
public struct MeetingBriefing: Sendable, Hashable, Identifiable {
    public let event: CalendarEventSummary
    public let people: [PersonBrief]

    public init(event: CalendarEventSummary, people: [PersonBrief]) {
        self.event = event
        self.people = people
    }

    public var id: String { event.occurrenceID }

    /// "Lunch with Alex", or "With Alex" for an untitled event.
    public var title: String {
        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "With \(peopleNames)" : trimmed
    }

    /// "Alex", "Alex and Sam", "Alex, Sam and Jo".
    public var peopleNames: String {
        let names = people.map(\.name)
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// One calm line for the notification and the Home card:
    /// "1 open promise · 2 things to bring up". Falls back to the people.
    public var summary: String {
        let promises = people.reduce(0) { $0 + $1.openPromises.count }
        let bringUp = people.reduce(0) { $0 + $1.toBringUp.count }
        let gifts = people.reduce(0) { $0 + $1.giftIdeas.count }
        var parts: [String] = []
        if promises > 0 { parts.append(promises == 1 ? "1 open promise" : "\(promises) open promises") }
        if bringUp > 0 { parts.append(bringUp == 1 ? "1 thing to bring up" : "\(bringUp) things to bring up") }
        if gifts > 0 { parts.append(gifts == 1 ? "a gift idea" : "\(gifts) gift ideas") }
        return parts.isEmpty ? "What you\u{2019}ve noted about \(peopleNames)" : parts.joined(separator: " \u{00B7} ")
    }
}

/// Timing and size limits for briefings, kept together so the surfaces
/// agree.
public enum MeetingBriefingPolicy {
    /// The notification comes this long before the event.
    public static let leadTime: TimeInterval = 30 * 60
    /// Home shows the card for events starting within this window…
    public static let homeWindow: TimeInterval = 3 * 60 * 60
    /// …and keeps it a little after they start, for latecomers.
    public static let startedGrace: TimeInterval = 15 * 60
    /// Events this far ahead are planned (notifications are rescheduled on
    /// every foreground, so this needn't be long).
    public static let lookahead: TimeInterval = 2 * 24 * 60 * 60
    public static let maxPeoplePerEvent = 3
    public static let recentMomentLimit = 3
    public static let giftIdeaLimit = 2

    /// When the briefing notification fires. All-day events ("Alex's
    /// birthday") get it on the morning of the day instead of 11:30 the
    /// night before.
    public static func notificationDate(for event: CalendarEventSummary, calendar: Calendar = .current) -> Date {
        event.isAllDay
            ? PersonReminderPlanner.alertDate(for: event, calendar: calendar)
            : event.start.addingTimeInterval(-leadTime)
    }

    /// Whether Home should show the briefing now.
    public static func isCurrent(_ event: CalendarEventSummary, now: Date, calendar: Calendar = .current) -> Bool {
        if event.isAllDay { return calendar.isDate(event.start, inSameDayAs: now) }
        let untilStart = event.start.timeIntervalSince(now)
        return untilStart <= homeWindow && untilStart >= -startedGrace
    }
}

/// Builds briefings for upcoming calendar events from memories and tasks.
public struct LoadMeetingBriefingsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let tasks: any TaskRepository

    public init(memories: any MemoryRepository, tasks: any TaskRepository) {
        self.memories = memories
        self.tasks = tasks
    }

    public func callAsFunction(events: [CalendarEventSummary]) async throws -> [MeetingBriefing] {
        guard !events.isEmpty else { return [] }
        let allMemories = try await memories.list(filter: MemoryFilter(sort: .newestFirst))
        let openTasks = try await tasks.openTasks()
        return Self.build(events: events, memories: allMemories, openTasks: openTasks)
    }

    /// Pure: one briefing per event that includes someone Orbit knows
    /// something about, soonest first. Events with nobody known are
    /// skipped, so a dentist appointment never gets an empty briefing.
    static func build(events: [CalendarEventSummary], memories: [Memory], openTasks: [MemoryTask]) -> [MeetingBriefing] {
        let live = memories.filter { !$0.isInTrash }.sorted { $0.createdAt > $1.createdAt }
        let people = knownPeople(memories: live, openTasks: openTasks)
        return events
            .sorted { $0.start < $1.start }
            .compactMap { event in
                let briefs = people
                    .filter { PersonReminderPlanner.includes($0.name, in: event) }
                    .map { brief(for: $0, memories: live, openTasks: openTasks) }
                    .filter { !$0.isEmpty }
                    .prefix(MeetingBriefingPolicy.maxPeoplePerEvent)
                return briefs.isEmpty ? nil : MeetingBriefing(event: event, people: Array(briefs))
            }
    }

    /// Everyone named in memories, promises or "next time I'm with…" tasks,
    /// one entry per person.
    private static func knownPeople(memories: [Memory], openTasks: [MemoryTask]) -> [MentionedEntity] {
        var people = ListMentionedEntitiesUseCase.summarize(memories, kind: .person, limit: nil)
        var seen = Set(people.map(\.key))
        for name in openTasks.flatMap({ [$0.promisedTo, $0.cue?.personName] }).compactMap({ $0 }) {
            let key = MentionedEntity.key(for: name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            people.append(MentionedEntity(kind: .person, name: name, key: key, memoryCount: 0, lastMentioned: .distantPast, lastContact: nil))
        }
        return people
    }

    private static func brief(for person: MentionedEntity, memories: [Memory], openTasks: [MemoryTask]) -> PersonBrief {
        let isThisPerson: (String?) -> Bool = { name in
            name.map { MentionedEntity.key(for: $0) == person.key } ?? false
        }
        let mentioning = memories.filter { memory in
            memory.mentionedNames(of: .person).contains { MentionedEntity.key(for: $0) == person.key }
        }
        let gifts = mentioning.filter { GiftIdeaDetector.isGiftIdea($0.analyzableText) }
        let giftIDs = Set(gifts.map(\.id))
        return PersonBrief(
            name: person.name,
            key: person.key,
            lastContact: person.lastContact,
            openPromises: openTasks.filter { isThisPerson($0.promisedTo) },
            toBringUp: openTasks.filter { isThisPerson($0.cue?.personName) },
            giftIdeas: Array(gifts.prefix(MeetingBriefingPolicy.giftIdeaLimit)),
            recentMoments: Array(mentioning.filter { !giftIDs.contains($0.id) }.prefix(MeetingBriefingPolicy.recentMomentLimit))
        )
    }
}

/// "Sam would love the green Le Creuset", "gift idea for Mom: a scarf".
/// Deliberately narrow: a false gift idea in a briefing is awkward.
enum GiftIdeaDetector {
    private static let pattern = #"(?i)\b(gift|gifts|present for|wish ?list|would love|has been wanting|always wanted|birthday idea)\b"#

    static func isGiftIdea(_ text: String) -> Bool {
        guard let regex = RegexCache.regex(pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
    }
}
