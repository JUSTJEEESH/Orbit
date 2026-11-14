import Foundation
import Testing
@testable import OrbitDomain

@Suite("Recently Deleted")
struct RecentlyDeletedTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeMemory(_ text: String) -> Memory {
        Memory(content: .text(text), createdAt: start, updatedAt: start)
    }

    @Test func deletingHidesTheMemoryButKeepsIt() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = makeMemory("Renew passport")
        try await repo.save(memory)

        try await MoveMemoryToTrashUseCase(repository: repo, clock: FixedClock(start))(id: memory.id)

        #expect(try await repo.list(filter: .all).isEmpty)
        #expect(try await repo.list(filter: .allIncludingSealed).isEmpty)
        #expect(try await repo.list(filter: .recentlyDeleted).map(\.id) == [memory.id])
        #expect(try await repo.memory(with: memory.id)?.content == .text("Renew passport"))
    }

    @Test func restoringBringsBackTheSameMemory() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = makeMemory("Renew passport")
        try await repo.save(memory)

        try await MoveMemoryToTrashUseCase(repository: repo, clock: FixedClock(start))(id: memory.id)
        try await RestoreMemoryUseCase(repository: repo)(id: memory.id)

        let restored = try #require(try await repo.list(filter: .all).first)
        #expect(restored == memory)
        #expect(try await repo.list(filter: .recentlyDeleted).isEmpty)
    }

    @Test func purgeRemovesOnlyMemoriesPastRetention() async throws {
        let repo = InMemoryMemoryRepository()
        let clock = FixedClock(start)
        let old = makeMemory("deleted long ago")
        let recent = makeMemory("deleted yesterday")
        let kept = makeMemory("never deleted")
        for memory in [old, recent, kept] { try await repo.save(memory) }

        let trash = MoveMemoryToTrashUseCase(repository: repo, clock: clock)
        try await trash(id: old.id)
        clock.advance(by: RecentlyDeletedPolicy.retention - 86_400)
        try await trash(id: recent.id)
        clock.advance(by: 2 * 86_400)

        let purged = try await PurgeExpiredTrashUseCase(repository: repo, clock: clock)()

        #expect(purged.map(\.id) == [old.id])
        #expect(try await repo.memory(with: old.id) == nil)
        #expect(try await repo.list(filter: .recentlyDeleted).map(\.id) == [recent.id])
        #expect(try await repo.list(filter: .all).map(\.id) == [kept.id])
    }

    @Test func deletingTwiceKeepsTheOriginalDeletionDate() async throws {
        let repo = InMemoryMemoryRepository()
        let clock = FixedClock(start)
        let memory = makeMemory("x")
        try await repo.save(memory)

        let trash = MoveMemoryToTrashUseCase(repository: repo, clock: clock)
        try await trash(id: memory.id)
        clock.advance(by: 3_600)
        try await trash(id: memory.id)

        #expect(try await repo.memory(with: memory.id)?.deletedAt == start)
    }
}
