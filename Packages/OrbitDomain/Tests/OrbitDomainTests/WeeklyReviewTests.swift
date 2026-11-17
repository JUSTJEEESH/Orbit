import Foundation
import Testing
@testable import OrbitDomain

@Suite("Weekly review")
struct WeeklyReviewTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func memory(_ text: String, daysAgo: Double, people: [String] = [], priority: MemoryAIMetadata.Priority = .normal,
                        media: [MediaAsset] = []) -> Memory {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        return Memory(
            content: .text(text), createdAt: date, updatedAt: date, media: media,
            ai: MemoryAIMetadata(status: .complete, summary: nil, category: nil, priority: priority,
                                 extractedDates: [], extractedPeople: people, extractedLocations: [])
        )
    }

    @Test func coversTheLastSevenDays() async throws {
        let recent = memory("Lunch with Sam", daysAgo: 1, people: ["Sam"])
        let alsoRecent = memory("Sam's new job", daysAgo: 3, people: ["Sam"])
        let old = memory("Trip planning", daysAgo: 40, people: ["Priya"])
        let promise = MemoryTask(title: "Send the photos", createdAt: now, promisedTo: "Sam")
        let chore = MemoryTask(title: "Fix the gate", createdAt: now)

        let review = try await GenerateWeeklyReviewUseCase(
            memories: InMemoryMemoryRepository(seed: [recent, alsoRecent, old]),
            tasks: InMemoryTaskRepository(seed: [promise, chore]),
            clock: FixedClock(now)
        )()

        #expect(review.memoryCount == 2)
        #expect(review.people.map(\.name) == ["Sam"])
        #expect(review.openPromises.map(\.title) == ["Send the photos"])
        #expect(review.openTasks.map(\.title) == ["Fix the gate"])
        // The only memory old enough to resurface.
        #expect(review.revisit?.id == old.id)
        #expect(!review.isEmpty)
    }

    @Test func importantAndRichMomentsRankFirst() {
        let plain = memory("ok", daysAgo: 1)
        let important = memory("Got the job offer", daysAgo: 2, priority: .high)
        let photo = memory("Beach day", daysAgo: 3,
                           media: [MediaAsset(kind: .image, filename: "beach.jpg", byteSize: 1, createdAt: now)])
        let moments = GenerateWeeklyReviewUseCase.bestMoments(in: [plain, important, photo])
        #expect(moments.map(\.id) == [important.id, photo.id, plain.id])
    }
}
