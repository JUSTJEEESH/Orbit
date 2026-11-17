import Foundation
import Testing
@testable import OrbitDomain

@Suite("Welcome back")
struct WelcomeBackTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test func quietAfterShortBreakOrFirstLaunch() async throws {
        let load = LoadWelcomeBackUseCase(tasks: InMemoryTaskRepository())
        #expect(try await load(lastVisit: nil, now: now) == nil)
        #expect(try await load(lastVisit: daysAgo(2), now: now) == nil)
    }

    @Test func promisesLeadThenSoonestDue() async throws {
        let later = MemoryTask(title: "Renew passport", dueDate: now.addingTimeInterval(30 * 86_400), createdAt: now)
        let sooner = MemoryTask(title: "Pay rent", dueDate: now.addingTimeInterval(86_400), createdAt: now)
        let promise = MemoryTask(title: "Send the photos", createdAt: now, promisedTo: "Sam")
        let undated = MemoryTask(title: "Fix the gate", createdAt: now)
        let done = MemoryTask(title: "Old", isCompleted: true, createdAt: now, completedAt: now)
        let repo = InMemoryTaskRepository(seed: [later, sooner, promise, undated, done])

        let welcome = try #require(try await LoadWelcomeBackUseCase(tasks: repo)(lastVisit: daysAgo(9), now: now))
        #expect(welcome.daysAway == 9)
        #expect(welcome.highlights.map(\.title) == ["Send the photos", "Pay rent", "Renew passport"])
        #expect(welcome.openCount == 4)
    }
}
