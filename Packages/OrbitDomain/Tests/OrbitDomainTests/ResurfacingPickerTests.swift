import Foundation
import Testing
@testable import OrbitDomain

@Suite("Resurfacing picker")
struct ResurfacingPickerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func memory(_ text: String, on created: Date, sealedUntil: Date? = nil, deleted: Bool = false) -> Memory {
        Memory(content: .text(text), createdAt: created, updatedAt: created,
               surfaceDate: sealedUntil, deletedAt: deleted ? created : nil)
    }

    @Test func prefersOnThisDayAndNeverRepeats() {
        let now = date(2026, 11, 14)
        let anniversary = memory("A year ago today", on: date(2025, 11, 15))
        let older = memory("Some old thought", on: date(2026, 3, 2))
        var rng = SystemRandomNumberGenerator()

        let picks = ResurfacingPicker().pick(
            from: [older, anniversary],
            for: [date(2026, 11, 15), date(2026, 11, 16), date(2026, 11, 17)],
            now: now, calendar: calendar, using: &rng
        )

        #expect(picks.count == 2)
        #expect(picks.first?.memory.id == anniversary.id)
        #expect(Set(picks.map(\.memory.id)).count == picks.count)
    }

    @Test func excludesRecentSealedDeletedAndEmptyMemories() {
        let now = date(2026, 11, 14)
        let recent = memory("Yesterday", on: date(2026, 11, 13))
        let sealed = memory("Letter", on: date(2025, 1, 1), sealedUntil: date(2030, 1, 1))
        let deleted = memory("Gone", on: date(2025, 1, 1), deleted: true)
        let empty = memory("   ", on: date(2025, 1, 1))
        var rng = SystemRandomNumberGenerator()

        let picks = ResurfacingPicker().pick(
            from: [recent, sealed, deleted, empty],
            for: [date(2026, 11, 15)], now: now, calendar: calendar, using: &rng
        )
        #expect(picks.isEmpty)
    }
}
