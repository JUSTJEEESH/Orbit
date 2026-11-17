import Foundation
import Testing
@testable import OrbitDomain

@Suite("Person reminders")
struct PersonReminderPlannerTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private func event(_ title: String, hoursAhead: Double, attendees: [String] = []) -> CalendarEventSummary {
        CalendarEventSummary(id: title, title: title, start: now.addingTimeInterval(hoursAhead * 3_600), attendeeNames: attendees)
    }

    @Test func matchesByTitleOrInviteeWholeWords() {
        #expect(PersonReminderPlanner.includes("Alex", in: event("Lunch with Alex", hoursAhead: 1)))
        #expect(PersonReminderPlanner.includes("Alex", in: event("Standup", hoursAhead: 1, attendees: ["Alex Rivera"])))
        #expect(PersonReminderPlanner.includes("Dad", in: event("Dad's birthday dinner", hoursAhead: 1)))
        #expect(!PersonReminderPlanner.includes("Alex", in: event("Coffee with Alexandra", hoursAhead: 1)))
    }

    @Test func picksTheNextMatchingEventAndSkipsDoneOrPast() {
        let ask = MemoryTask(title: "Ask about the trip", createdAt: now, cue: .person("Alex"))
        let done = MemoryTask(title: "Old", isCompleted: true, createdAt: now, completedAt: now, cue: .person("Alex"))
        let noCue = MemoryTask(title: "Buy milk", createdAt: now)
        let events = [
            event("Dinner with Alex", hoursAhead: 30),
            event("Lunch with Alex", hoursAhead: 3),
            event("Breakfast with Alex", hoursAhead: -2),
        ]
        let plans = PersonReminderPlanner.plan(tasks: [ask, done, noCue], events: events, now: now)
        #expect(plans.count == 1)
        #expect(plans.first?.taskID == ask.id)
        #expect(plans.first?.eventTitle == "Lunch with Alex")
        #expect(plans.first?.fireDate == now.addingTimeInterval(3 * 3_600))
    }

    @Test func noEventMeansNoAlert() {
        let ask = MemoryTask(title: "Ask about the trip", createdAt: now, cue: .person("Alex"))
        #expect(PersonReminderPlanner.plan(tasks: [ask], events: [event("Dentist", hoursAhead: 2)], now: now).isEmpty)
    }
}
