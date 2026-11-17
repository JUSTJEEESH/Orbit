import Foundation
import Testing
@testable import OrbitDomain

@Suite("Before-you-meet briefings")
struct MeetingBriefingTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func event(_ title: String, hoursAhead: Double, attendees: [String] = [], allDay: Bool = false) -> CalendarEventSummary {
        CalendarEventSummary(
            id: title, title: title, start: now.addingTimeInterval(hoursAhead * 3_600),
            attendeeNames: attendees, isAllDay: allDay
        )
    }

    private func memory(_ text: String, people: [String], daysAgo: Double) -> Memory {
        let created = now.addingTimeInterval(-daysAgo * 86_400)
        var ai = MemoryAIMetadata.pending
        ai.extractedPeople = people
        return Memory(content: .text(text), createdAt: created, updatedAt: created, ai: ai)
    }

    @Test func gathersPromisesThingsToBringUpGiftsAndMoments() throws {
        let memories = [
            memory("Alex would love the new Murakami book", people: ["Alex"], daysAgo: 20),
            memory("Alex's kids are Mia and Leo", people: ["Alex"], daysAgo: 10),
            memory("Called Alex about the move", people: ["Alex"], daysAgo: 3),
            memory("Dinner with Sam", people: ["Sam"], daysAgo: 1),
        ]
        let promise = MemoryTask(title: "Send Alex the photos", createdAt: now, promisedTo: "Alex")
        let bringUp = MemoryTask(title: "Ask about the trip", createdAt: now, cue: .person("Alex"))
        let unrelated = MemoryTask(title: "Buy milk", createdAt: now)

        let briefings = LoadMeetingBriefingsUseCase.build(
            events: [event("Lunch with Alex", hoursAhead: 2)],
            memories: memories,
            openTasks: [promise, bringUp, unrelated]
        )
        let brief = try #require(briefings.first?.people.first)
        #expect(brief.name == "Alex")
        #expect(brief.openPromises == [promise])
        #expect(brief.toBringUp == [bringUp])
        #expect(brief.giftIdeas.map(\.analyzableText) == ["Alex would love the new Murakami book"])
        // Newest first, gift idea not repeated.
        #expect(brief.recentMoments.map(\.analyzableText) == ["Called Alex about the move", "Alex's kids are Mia and Leo"])
        #expect(briefings.first?.summary == "1 open promise \u{00B7} 1 thing to bring up \u{00B7} a gift idea")
    }

    @Test func skipsEventsWithNobodyKnown() {
        let briefings = LoadMeetingBriefingsUseCase.build(
            events: [event("Dentist", hoursAhead: 1), event("Coffee with Jordan", hoursAhead: 2)],
            memories: [memory("Called Alex", people: ["Alex"], daysAgo: 1)],
            openTasks: []
        )
        #expect(briefings.isEmpty)
    }

    @Test func peopleOnlyInTasksStillGetABriefing() {
        let promise = MemoryTask(title: "Return the drill", createdAt: now, promisedTo: "Priya")
        let briefings = LoadMeetingBriefingsUseCase.build(
            events: [event("Standup", hoursAhead: 1, attendees: ["Priya Shah"])],
            memories: [],
            openTasks: [promise]
        )
        #expect(briefings.first?.people.first?.openPromises == [promise])
    }

    @Test func eachOccurrenceOfARepeatingEventIsItsOwnBriefing() {
        let memories = [memory("Called Alex", people: ["Alex"], daysAgo: 1)]
        let first = CalendarEventSummary(id: "weekly", title: "1:1 with Alex", start: now.addingTimeInterval(3_600), attendeeNames: [])
        let second = CalendarEventSummary(id: "weekly", title: "1:1 with Alex", start: now.addingTimeInterval(8 * 86_400), attendeeNames: [])
        let briefings = LoadMeetingBriefingsUseCase.build(events: [second, first], memories: memories, openTasks: [])
        #expect(briefings.count == 2)
        #expect(Set(briefings.map(\.id)).count == 2)
        #expect(briefings.first?.event.start == first.start)
    }

    @Test func trashedMemoriesAreLeftOut() {
        var trashed = memory("Alex wants a new wallet for a gift", people: ["Alex"], daysAgo: 1)
        trashed.deletedAt = now
        let briefings = LoadMeetingBriefingsUseCase.build(
            events: [event("Lunch with Alex", hoursAhead: 1)], memories: [trashed], openTasks: []
        )
        #expect(briefings.isEmpty)
    }

    @Test func notificationTiming() {
        let lunch = event("Lunch with Alex", hoursAhead: 2)
        #expect(MeetingBriefingPolicy.notificationDate(for: lunch) == lunch.start.addingTimeInterval(-30 * 60))

        let birthday = event("Alex's birthday", hoursAhead: 24, allDay: true)
        let fire = MeetingBriefingPolicy.notificationDate(for: birthday, calendar: utc)
        #expect(utc.component(.hour, from: fire) == PersonReminderPlanner.allDayAlertHour)
        #expect(utc.isDate(fire, inSameDayAs: birthday.start))
    }

    @Test func homeShowsBriefingsFromThreeHoursBeforeToJustAfterStart() {
        #expect(MeetingBriefingPolicy.isCurrent(event("A", hoursAhead: 2.5), now: now))
        #expect(!MeetingBriefingPolicy.isCurrent(event("B", hoursAhead: 4), now: now))
        #expect(MeetingBriefingPolicy.isCurrent(event("C", hoursAhead: -0.1), now: now))
        #expect(!MeetingBriefingPolicy.isCurrent(event("D", hoursAhead: -1), now: now))
    }

    @Test func giftIdeasAreNarrow() {
        #expect(GiftIdeaDetector.isGiftIdea("Gift idea for Mom: a scarf"))
        #expect(GiftIdeaDetector.isGiftIdea("Sam has been wanting a record player"))
        #expect(!GiftIdeaDetector.isGiftIdea("Sam was present at the meeting"))
        #expect(!GiftIdeaDetector.isGiftIdea("Had lunch with Sam"))
    }

    @Test func allDayPersonRemindersRingInTheMorning() {
        let ask = MemoryTask(title: "Ask about the trip", createdAt: now, cue: .person("Alex"))
        let birthday = event("Alex's birthday", hoursAhead: 24, allDay: true)
        let plan = PersonReminderPlanner.plan(tasks: [ask], events: [birthday], now: now, calendar: utc).first
        #expect(plan.map { utc.component(.hour, from: $0.fireDate) } == PersonReminderPlanner.allDayAlertHour)
    }
}
