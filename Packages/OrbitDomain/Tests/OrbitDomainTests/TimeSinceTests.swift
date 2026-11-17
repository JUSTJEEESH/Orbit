import Foundation
import Testing
@testable import OrbitDomain

@Suite("Time since")
struct TimeSinceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func countsCalendarDaysNotHours() {
        // 11 pm to 1 am is two hours but one calendar day.
        let lateNight = date(2026, 3, 1, hour: 23)
        let earlyMorning = date(2026, 3, 2, hour: 1)
        #expect(TimeSince.days(from: lateNight, to: earlyMorning, calendar: calendar) == 1)
        #expect(TimeSince.phrase(from: lateNight, to: earlyMorning, calendar: calendar) == "yesterday")
    }

    @Test func phrasesReadNaturally() {
        let now = date(2026, 6, 30)
        #expect(TimeSince.phrase(from: date(2026, 6, 30, hour: 8), to: now, calendar: calendar) == "today")
        #expect(TimeSince.phrase(from: date(2026, 6, 7), to: now, calendar: calendar) == "23 days ago")
        #expect(TimeSince.phrase(from: date(2026, 3, 30), to: now, calendar: calendar) == "about 3 months ago")
        #expect(TimeSince.phrase(from: date(2025, 3, 1), to: now, calendar: calendar) == "over a year ago")
        #expect(TimeSince.phrase(from: date(2023, 1, 1), to: now, calendar: calendar) == "over 3 years ago")
    }

    @Test func futureDatesClampToToday() {
        let now = date(2026, 6, 30)
        #expect(TimeSince.days(from: date(2026, 7, 4), to: now, calendar: calendar) == 0)
    }
}
